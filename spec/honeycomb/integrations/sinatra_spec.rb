# frozen_string_literal: true

require "rack/test"
require "sinatra/base"

RSpec.describe Honeycomb::Rack do
  include Rack::Test::Methods

  class App < Sinatra::Application
    get "/" do
      "Hello world"
    end
  end

  let(:libhoney_client) { Libhoney::TestClient.new }

  let(:app) { App }

  before do
    app.use Honeycomb::Rack,
            client: Honeycomb::Client.new(client: libhoney_client)
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

  it_behaves_like "event data"
end
