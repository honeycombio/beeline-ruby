# frozen_string_literal: true

require "libhoney"

# libhoney_client = Libhoney::NullClient.new
libhoney_client = Libhoney::LogClient.new

RSpec.describe Honeycomb::Beeline do
  it "has a version number" do
    expect(Honeycomb::Beeline::VERSION).not_to be nil
  end
end

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
end

RSpec.shared_examples "a tracing object" do
  it "can add fields" do
    subject.add_field("key", "value")
  end

  it "can add rollup fields" do
    subject.add_rollup_field("key", 1)
  end

  it "can be sent" do
    subject.send
  end
end

RSpec.describe Honeycomb::Trace do
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  subject(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }
  it_behaves_like "a tracing object"
end

RSpec.describe Honeycomb::Span do
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  let(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }
  subject(:span) do
    Honeycomb::Span.new(trace: trace, builder: builder, context: context)
  end
  it_behaves_like "a tracing object"

  it "can add hashes" do
    span.add("key" => "value", "more" => "values")
  end

  it "can add trace fields" do
    span.add_trace_field("key", "value")
  end
end
