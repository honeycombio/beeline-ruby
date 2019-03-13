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

  it "can create a trace without using a block" do
    outer_span = client.start_span(name: "test")
    client.add_field "test", "wow"
    client.start_span(name: "inner-one") do # |inner_span|
      client.add_field("inner count", 1)
    end
    client.start_span(name: "inner-two") do # |inner_span|
      client.add_field("inner count", 1)
    end
    outer_span.send

    expect(libhoney_client.events.size).to eq 3
  end

  it "can create a trace and add error details" do
    expect do
      client.start_span(name: "test error") do
        raise(ArgumentError, "an argument!")
      end
    end.to raise_error(ArgumentError, "an argument!")
    expect(libhoney_client.events.size).to eq 1
  end

  it "can add field to trace" do
    client.start_span(name: "trace fields") do
      client.add_field_to_trace "useless_info", 42
    end
    expect(libhoney_client.events.size).to eq 1
  end

  it "send the whole trace when sending the parent" do
    root_span = client.start_span(name: "root")
    client.start_span(name: "mid")
    client.start_span(name: "leaf")
    root_span.send
    expect(libhoney_client.events.size).to eq 3
  end
end
