# frozen_string_literal: true

require "faraday"
require "honeycomb/integrations/faraday"

RSpec.describe Honeycomb::Faraday do
  it "works" do
    connection = Faraday.new do |conn|
      conn.use Honeycomb::Faraday,
               client: Honeycomb::Client.new(client: Libhoney::LogClient.new)
      conn.adapter Faraday.default_adapter
    end

    response = connection.get "https://www.honeycomb.io/overview/"
    expect(response.env[:url].to_s).to eq("https://www.honeycomb.io/overview/")
  end
end
