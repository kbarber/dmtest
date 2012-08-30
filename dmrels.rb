#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require :default, :development

DM = DataMapper
UAPWM = DM::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
DM::Logger.new(STDOUT, :debug)
DM.setup(:default, 'sqlite3::memory:')
DM.repository(:default).adapter.resource_naming_convention = UAPWM
DM::Model.raise_on_save_failure = true
DM.finalize

class Release
  include DataMapper::Resource

  belongs_to :module, 'Mod'
  property :id, Serial
end

class Mod
  include DataMapper::Resource

  has n, :releases, child_key: [ :module_id ], model: Release
  belongs_to :user
  property :id, Serial
end

class User
  include DataMapper::Resource

  has n, :modules, model: Mod
  property :id, Serial
end

DM.auto_migrate!

begin
  user = User.create()
  mod = Mod.create(:user => user)
  release1 = Release.create(:module => mod)
  release2 = Release.create(:module => mod)

  puts mod.releases.inspect
rescue DataMapper::SaveFailureError => e
  puts e.message
  puts e.resource.errors.full_messages.join(", ")
end

