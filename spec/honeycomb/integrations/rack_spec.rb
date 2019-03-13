# frozen_string_literal: true

require "rack/test"
require "rack/lobster"

RSpec.describe Honeycomb::Rack do
  include Rack::Test::Methods
  let(:lobster) { Rack::Lobster.new }
  let(:linted_lobster) { Rack::Lint.new(lobster) }
  let(:app) do
    Honeycomb::Rack.new(linted_lobster,
                        client: Honeycomb::Client.new(client: libhoney_client))
  end
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:event_data) { libhoney_client.events.map(&:data) }

  describe "standard request" do
    before do
      get "/"
    end

    it "returns ok" do
      expect(last_response).to be_ok
    end

    it "sends a single event" do
      expect(libhoney_client.events.size).to eq 1
    end

    it_behaves_like "event data"
  end

  describe "trace header request" do
    let(:serialized_trace) do
      "1;trace_id=wow,parent_id=eep,dataset=test_dataset"
    end

    before do
      header("X-Honeycomb-Trace", serialized_trace)
      get "/"
    end

    it "returns ok" do
      expect(last_response).to be_ok
    end

    it "sends a single event" do
      expect(libhoney_client.events.size).to eq 1
    end

    it_behaves_like "event data"
  end
end
