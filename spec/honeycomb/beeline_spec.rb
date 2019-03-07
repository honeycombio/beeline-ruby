# frozen_string_literal: true

require "libhoney"

# libhoney_client = Libhoney::NullClient.new
libhoney_client = Libhoney::LogClient.new

RSpec.describe Honeycomb do
  it "can be configured" do
    Honeycomb.configure do |config|
      config.write_key = "write_key"
      config.dataset = "dataset"
      config.service_name = "service_name"
    end
  end
end

RSpec.describe Honeycomb::Configuration do
  it "uses the dataset name as the service_name when not provided" do
    configuration = Honeycomb::Configuration.new
    configuration.dataset = "dataset"
    expect(configuration.service_name).to eq "dataset"
  end
end

RSpec.describe Honeycomb::Beeline do
  it "has a version number" do
    expect(Honeycomb::Beeline::VERSION).not_to be nil
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
