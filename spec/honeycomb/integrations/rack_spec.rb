# frozen_string_literal: true

require "rack/test"

RSpec.describe Honeycomb::Rack do
  include Rack::Test::Methods

  def app
    libhoney_client = Libhoney::LogClient.new
    client = Honeycomb::Client.new(client: libhoney_client)
    Rack::Builder.new do
      use Rack::Lint
      use Honeycomb::Rack, client: client
      run ->(_env) { [200, {}, ["Hello world"]] }
    end.to_app
  end

  it "works" do
    get "/"
    expect(last_response).to be_ok
  end
end
