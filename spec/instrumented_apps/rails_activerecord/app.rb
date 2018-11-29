require 'rails'
require 'action_controller/railtie'
require 'active_record/railtie'

require 'honeycomb-beeline'

require 'support/db_active_record'
require 'support/fake_auth'
require 'support/fakehoney'
require 'support/only_one_app'
require 'support/test_logger'

Honeycomb.init service_name: 'rails_activerecord', client: $fakehoney, logger: $test_logger

class RailsActiveRecordApp < Rails::Application
  include ThereCanBeOnlyOneApp

  # some minimal config Rails expects to be present
  if Rails::VERSION::MAJOR < 4
    config.secret_token = 'test' * 8
  else
    config.secret_key_base = 'test'
  end

  config.eager_load = true

  # override Rails DB config to use our test DB
  # (normally Rails would look in config/database.yml)
  def config.database_configuration
    TestDB::ActiveRecord.config
  end

  routes.append do
    post '/login', to: 'sessions#create'

    resources :animals do
      get '/remote', action: :index_remote, on: :collection
    end

    if Rails::VERSION::MAJOR < 4
      root to: 'hello#index'
    else
      root 'hello#index'
    end
  end

  FAKE_AUTH = FakeAuth::Client.new
end

class ApplicationController < ActionController::Base
  def render_plain(text)
    if Rails::VERSION::MAJOR < 4
      render text: text
    else
      render plain: text
    end
  end
end

class HelloController < ApplicationController
  def index
    render_plain 'hello'
  end
end

class SessionsController < ApplicationController
  def create
    user = RailsActiveRecordApp::FAKE_AUTH.login
    render_plain "logged in as #{user.fetch('username')}"
  end
end

class AnimalsController < ApplicationController
  def index_remote
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
      render json: (animals1 + animals2)
    end
  end

  def create
    # N.B. this is not actually a correct way to do "add a new record if one
    # doesn't already exist", but this is an example of ActiveRecord usage,
    # not of concurrency-safe database best practices!

    if animal = Animal.find_by(name: params.require(:name))
      render status: :accepted, json: animal
    else
      animal = Animal.create!(params.permit(:name, :species))
      render status: :created, json: animal
    end
  end

  private
  def span(name:)
    Honeycomb.span(service_name: :rails_activerecord, name: name) { yield }
  end
end
