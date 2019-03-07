# frozen_string_literal: true

require "libhoney"

# libhoney_client = Libhoney::NullClient.new
libhoney_client = Libhoney::LogClient.new

RSpec.describe Honeycomb::Client do
  subject(:client) { Honeycomb::Client.new(client: libhoney_client) }
  it "can create a trace" do
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
  end

  it "can create a trace and add error details" do
    expect do
      client.start_span(name: "test error") do
        raise(ArgumentError, "an argument!")
      end
    end.to raise_error(ArgumentError, "an argument!")
  end

  it "can add field to trace" do
    client.start_span(name: "trace fields") do
      client.add_field_to_trace "useless_info", 42
    end
  end

  it "send the whole trace when sending the parent" do
    root_span = client.start_span(name: "root")
    client.start_span(name: "mid")
    client.start_span(name: "leaf")
    root_span.send
  end
end
