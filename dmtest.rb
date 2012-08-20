#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require :default, :development

DM = DataMapper

class User
  include DataMapper::Resource

  has n, :mods

  property :id, Serial
end

class Mod
  include DataMapper::Resource

  belongs_to :user
  has n, :releases

  property :id, Serial
end

class Release
  include DataMapper::Resource

  belongs_to :mod

  property :id, Serial
end

UAPWM = DM::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
DM.setup(:default, 'sqlite3::memory:')
DM.repository(:default).adapter.resource_naming_convention = UAPWM
DM::Model.raise_on_save_failure = true
DM.finalize
DM.auto_migrate!

user = User.create()
mod = Mod.create(:user => user)
release = Release.create(:mod => mod)
