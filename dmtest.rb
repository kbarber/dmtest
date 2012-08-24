#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require :default, :development

module DataMapper::Migrations::DataObjectsAdapter::SQL
  alias :property_schema_hash_orig :property_schema_hash
  def property_schema_hash(property)
    schema = property_schema_hash_orig(property)
    schema.delete(:length) if schema[:primitive] == 'BYTEA'
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
      case DataMapper.repository(:default).adapter.class.to_s
      when /SqliteAdapter/ then super
      when /PostgresAdapter/ then PGconn.unescape_bytea(super)
      else super
      end
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

puts DM.repository(:default).adapter.class.to_s

file = File.open("/bin/ls", 'rb')
file_data = file.read

class String
  def hex2bin
    s = self
    raise "Not a valid hex string" unless(s =~ /^[\da-fA-F]+$/)
    s = '0' + s if((s.length & 1) != 0)
    s.scan(/../).map{ |b| b.to_i(16) }.pack('C*')
  end

  def bin2hex
    self.unpack('C*').map{ |b| "%02X" % b }.join('')
  end
end

begin
  user = User.create()
  mod = Mod.create(:user => user)
  release = Release.create(:module => mod, :version => '1.1')

  adapter = DM.repository(:default).adapter
  statement = case adapter.class.to_s
  when /SqliteAdapter/ then "update releases set file_data = X'#{file_data.bin2hex}' where id = #{release.id}"
  when /PostgresAdapter/ then "update releases set file_data = '#{PGconn.escape_bytea(file_data)}' where id = #{release.id}"
  else
    puts "Invalid database"
    exit(1)
  end
  adapter.execute(statement)
  puts "Statement is: #{statement}"

  new_file = Release.first(:module => mod).file_data
  puts new_file.length
  File.unlink("ls")
  filenew = File.open("ls", "wb")
  filenew.write(new_file)
rescue DataMapper::SaveFailureError => e
  puts "Class: #{e.resource}"
  puts e.resource.errors.full_messages.join(",")
end
