# frozen_string_literal: true

require "rack/test"
require "sinatra/base"

RSpec.describe Honeycomb::Rack do
  include Rack::Test::Methods

  class App < Sinatra::Application
    use Honeycomb::Rack,
        client: Honeycomb::Client.new(client: Libhoney::LogClient.new)
    get "/" do
      "Hello world"
    end
  end

  def app
    App
  end

  it "works" do
    get "/"
    expect(last_response).to be_ok
  end
end
