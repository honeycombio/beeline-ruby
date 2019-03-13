# frozen_string_literal: true

require "faraday"
require "honeycomb/integrations/faraday"

RSpec.describe Honeycomb::Faraday do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:connection) do
    Faraday.new do |conn|
      conn.use Honeycomb::Faraday,
               client: Honeycomb::Client.new(client: libhoney_client)
      conn.adapter Faraday.default_adapter
    end
  end

  let!(:response) { connection.get "https://www.honeycomb.io/overview/" }

  it "has the right url in the response" do
    expect(response.env[:url].to_s).to eq("https://www.honeycomb.io/overview/")
  end

  it "sends the right amount of events" do
    expect(libhoney_client.events.size).to eq 1
  end

  let(:event_data) { libhoney_client.events.map(&:data) }

  it_behaves_like "event data"
end
