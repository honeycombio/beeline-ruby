# frozen_string_literal: true

require "libhoney"

client = Libhoney::NullClient.new

RSpec.describe Honeycomb::Beeline do
  it "has a version number" do
    expect(Honeycomb::Beeline::VERSION).not_to be nil
  end
end

RSpec.describe Honeycomb::Client do
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
  let(:builder) { client.builder }
  subject(:trace) { Honeycomb::Trace.new(builder: builder) }
  it_behaves_like "a tracing object"
end

RSpec.describe Honeycomb::Span do
  let(:builder) { client.builder }
  let(:trace) { Honeycomb::Trace.new(builder: builder) }
  subject(:span) { Honeycomb::Span.new(trace: trace, builder: builder) }
  it_behaves_like "a tracing object"

  it "can add hashes" do
    span.add("key" => "value", "more" => "values")
  end

  it "can add trace fields" do
    span.add_trace_field("key", "value")
  end
end
