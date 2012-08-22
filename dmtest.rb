#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require :default, :development

Encoding.default_internal = "BINARY"

DM = DataMapper

class Release
  include DataMapper::Resource

  belongs_to :module, :model => 'Mod'
  property :id, Serial
  property :version, String
  property :file_data, Binary, :length => 16 * 1024 * 1024, :required => false

=begin
  def file_data=(data)
    super(PGconn.escape_bytea(data))
  end

  def file_data
    if fd = super
      PGconn.unescape_bytea(fd)
    end
  end
=end
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

begin
  user = User.create()
  mod = Mod.create(:user => user)
  release = Release.create(:module => mod, :version => '1.1')

  file = File.open("/bin/ls", "rb")
  file_data = file.read
  puts file_data.length
  file_data = PGconn.escape_bytea(file_data)
  DM.repository(:default).adapter.execute("update releases set file_data = ? where id = #{release.id}", file_data)
  #DM.repository(:default).adapter.execute("update releases set file_data = '#{file_data}' where id = #{release.id}")
  #release.file_data = file_data
  #release.save

  new_file = Release.first(:module => mod).file_data
  new_file = PGconn.unescape_bytea(new_file)
  puts new_file.length
  File.unlink("ls")
  filenew = File.open("ls", "wb")
  filenew.write(new_file)

rescue DataMapper::SaveFailureError => e
  puts "Class: #{e.resource}"
  puts e.resource.errors.full_messages.join(",")
end
