require 'json'
require 'sinatra/base'

require 'honeycomb-beeline'

require 'support/db_sequel'
require 'support/fakehoney'
require 'support/only_one_app'

Honeycomb.init service_name: 'sinatra_sequel', client: $fakehoney

class SinatraSequelApp < Sinatra::Base
  include ThereCanBeOnlyOneApp

  set :environment, 'test'
  set :raise_errors, true

  get '/' do
    'hello'
  end

  put '/animals' do
    content_type :json

    animal_props = JSON.parse request.body.read

    # N.B. this is not actually a correct way to do "add a new record if one
    # doesn't already exist", but this is an example of ActiveRecord usage,
    # not of concurrency-safe database best practices!

    if animal = TestDB::Sequel.Animals.where(name: animal_props.fetch('name')).first
      status 202
      animal.to_json
    else
      id = TestDB::Sequel.Animals.insert(animal_props)
      status 201
      animal_props.merge('id' => id).to_json
    end
  end
end

