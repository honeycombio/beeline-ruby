# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb::Client do
  let(:libhoney_client) { Libhoney::TestClient.new }
  subject(:client) { Honeycomb::Client.new(client: libhoney_client) }

  describe "creating a trace" do
    before do
      client.start_span(name: "test") do # |span|
        client.add_field "test", "wow"
        client.start_span(name: "inner-one") do # |inner_span|
          client.add_field("inner count", 1)
        end
        client.start_span(name: "inner-two") do # |inner_span|
          client.add_field("inner count", 1)
        end
      end
      client.start_span(name: "second trace") do
        client.add_field "test", "wow"
      end
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 4
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end

  describe "can create a trace without using a block" do
    before do
      outer_span = client.start_span(name: "test")
      client.add_field "test", "wow"
      client.start_span(name: "inner-one") do # |inner_span|
        client.add_field("inner count", 1)
      end
      client.start_span(name: "inner-two") do # |inner_span|
        client.add_field("inner count", 1)
      end
      outer_span.send
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 3
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end

  describe "can create a trace and add error details" do
    before do
      expect do
        client.start_span(name: "test error") do
          raise(ArgumentError, "an argument!")
        end
      end.to raise_error(ArgumentError, "an argument!")
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data",
                    package_fields: false,
                    additional_fields: ["request.error", "request.error_detail"]
  end

  describe "can add field to trace" do
    before do
      client.start_span(name: "trace fields") do
        client.add_field_to_trace "useless_info", 42
      end
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data",
                    package_fields: false,
                    additional_fields: ["app.useless_info"]
  end

  describe "send the whole trace when sending the parent" do
    before do
      root_span = client.start_span(name: "root")
      client.start_span(name: "mid")
      client.start_span(name: "leaf")
      root_span.send
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 3
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end
end
