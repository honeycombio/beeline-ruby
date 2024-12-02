# frozen_string_literal: true

if defined?(Honeycomb::Sinatra)
  require "rack/test"
  require "sinatra/base"

  RSpec.describe Honeycomb::Sinatra do
    include Rack::Test::Methods

    class App < Sinatra::Application
      set :host_authorization, permitted_hosts: []

      get "/" do
        "Hello world"
      end
    end

    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }

    let(:app) { App }

    before do
      app.use Honeycomb::Sinatra::Middleware,
              client: client
    end

    before do
      get "/"
    end

    it "returns ok" do
      expect(last_response).to be_ok
    end

    it "sends a single event" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", additional_fields: ["request.route"]
  end
end
