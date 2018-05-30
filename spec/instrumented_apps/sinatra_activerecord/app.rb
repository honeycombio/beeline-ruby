require 'json'
require 'sinatra/base'

require 'honeycomb-beeline'

require 'support/db_active_record'
require 'support/fakehoney'
require 'support/only_one_app'

Honeycomb.init service_name: 'sinatra_activerecord', client: $fakehoney

class SinatraActiveRecordApp < Sinatra::Base
  include ThereCanBeOnlyOneApp

  set :environment, 'test'
  set :raise_errors, true

  def auth_client
    @auth_client ||= Faraday.new('https://auth.example.com') do |conn|
      conn.adapter :test do |stub|
        stub.post('/login') { [200, {}, {username: 'Bob'}.to_json] }
      end
    end
  end

  get '/' do
    'hello'
  end

  post '/login' do
    response = auth_client.post('/login')
    if response.status == 200
      user = JSON.parse(response.body)
      status 200
      "logged in as #{user.fetch('username')}"
    else
      status 401
      'not logged in'
    end
  end

  put '/animals' do
    content_type :json

    animal_props = JSON.parse request.body.read

    # N.B. this is not actually a correct way to do "add a new record if one
    # doesn't already exist", but this is an example of ActiveRecord usage,
    # not of concurrency-safe database best practices!

    if animal = Animal.find_by(name: animal_props.fetch('name'))
      status 202
    else
      animal = Animal.create!(animal_props)
      status 201
    end
    animal.to_json
  end

  get '/microanimals' do
    # simulate user instrumentation for calling a couple of microservices

    animals1 = span name: :reindeer_games_service do
      %w(Dasher Dancer Prancer Vixen Comet Cupid Donner Blitzen).map do |name|
        Animal.new name: name, species: 'Reindeer'
      end
    end

    animals2 = span name: :nose_so_bright_service do
      [Animal.new(name: 'Rudolph', species: 'Reindeer')]
    end

    span name: :render_json do
      (animals1 + animals2).to_json
    end
  end

  private
  def span(name:)
    Honeycomb.span(service_name: :sinatra_activerecord, name: name) { yield }
  end
end
