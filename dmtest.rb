#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require :default, :development

module DataMapper::Migrations::DataObjectsAdapter::SQL
  alias :property_schema_hash_orig :property_schema_hash
  def property_schema_hash(property)
    schema = property_schema_hash_orig(property)
    if schema[:primitive] == 'BYTEA'
      schema.delete(:length)
    end
    schema
  end
end

DM = DataMapper

class Release
  include DataMapper::Resource

  belongs_to :module, :model => 'Mod'
  property :id, Serial
  property :version, String
  property :file_data, Binary, :length => 16 * 1024 * 1024, :required => false

  def file_data
    if fd = super
      PGconn.unescape_bytea(super)
    end
  end
end

class Mod
  include DataMapper::Resource

  belongs_to :user
  property :id, Serial
end

class User
  include DataMapper::Resource

  property :id, Serial
end

UAPWM = DM::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
DM::Logger.new(STDOUT, :debug)
#DM.setup(:default, 'sqlite3:///Users/ken/Development/dmtest/db.sqlite3')
DM.setup(:default, 'postgres://dmtest:dmtest@localhost/dmtest')
DM.repository(:default).adapter.resource_naming_convention = UAPWM
DM::Model.raise_on_save_failure = true
DM.finalize
DM.auto_migrate!

file = File.open("/bin/ls", 'rb')
file_data = file.read

begin
  user = User.create()
  mod = Mod.create(:user => user)
  release = Release.create(:module => mod, :version => '1.1')

  puts file_data.length
  file_data = PGconn.escape_bytea(file_data)

  #DM.repository(:default).adapter.execute("update releases set file_data = ? where id = ?", file_data, release.id)
  DM.repository(:default).adapter.execute("update releases set file_data = '#{file_data}' where id = #{release.id}")

  new_file = Release.first(:module => mod).file_data
  puts new_file.length
  File.unlink("ls")
  filenew = File.open("ls", "wb")
  filenew.write(new_file)

rescue DataMapper::SaveFailureError => e
  puts "Class: #{e.resource}"
  puts e.resource.errors.full_messages.join(",")
end
