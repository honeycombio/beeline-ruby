# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb do
  let(:libhoney_client) { Libhoney::TestClient.new }

  before do
    Honeycomb.configure do |config|
      config.write_key = "write_key"
      config.dataset = "dataset"
      config.service_name = "service_name"
      config.client = libhoney_client
    end
  end

  describe "when using a block" do
    before do
      Honeycomb.start_span(name: "test") do
      end
    end

    it "sends the right amount of events" do
      expect(libhoney_client.events.size).to eq 1
    end
  end

  describe "manually sending" do
    before do
      span = Honeycomb.start_span(name: "test")
      span.send
    end

    it "sends the right amount of events" do
      expect(libhoney_client.events.size).to eq 1
    end
  end
end

RSpec.describe Honeycomb::Configuration do
  let(:configuration) { Honeycomb::Configuration.new }
  let(:dataset_name) { "dataset" }
  let(:service_name) { "service_name" }
  let(:write_key) { "service_name" }
  let(:api_host) { "https://www.honeycomb.io" }
  let(:event) { configuration.client.event }

  before do
    configuration.write_key = write_key
    configuration.dataset = dataset_name
    configuration.api_host = api_host
  end

  it "has a default service_name" do
    expect(configuration.service_name).to eq dataset_name
  end

  it "has the correct write_key" do
    expect(configuration.write_key).to eq write_key
  end

  it "has the correct dataset" do
    expect(configuration.dataset).to eq dataset_name
  end

  it "has the correct api_host" do
    expect(configuration.api_host).to eq api_host
  end

  it "has a client that is the correct type" do
    expect(configuration.client).to be_a Libhoney::Client
  end

  it "configures the client with the correct write_key" do
    expect(event.writekey).to be write_key
  end

  it "configures the client with the correct dataset" do
    expect(event.dataset).to be dataset_name
  end

  it "configures the client with the correct api_host" do
    expect(event.api_host).to be api_host
  end

  describe "configured service_name" do
    before do
      configuration.service_name = service_name
    end

    it "uses the provided service_name" do
      expect(configuration.service_name).to eq service_name
    end
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
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  subject(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }

  let(:trace_fields) { { "wow" => 420 } }
  let(:trace_header) { trace.root_span.to_trace_header }
  let(:distributed_trace) do
    Honeycomb::Trace.new(builder: builder,
                         context: context,
                         serialized_trace: trace_header)
  end

  before do
    trace_fields.each do |key, value|
      trace.add_field key, value
    end
  end

  it_behaves_like "a tracing object"

  describe "distributed tracing" do
    it "preserves the trace_id" do
      expect(distributed_trace.id).to eq trace.id
    end

    it "preserves the parent_id" do
      root_span = distributed_trace.root_span
      parent_id = root_span.instance_variable_get("@parent_id")
      expect(parent_id).to eq trace.root_span.id
    end

    it "preserves the trace_fields" do
      expect(distributed_trace.fields).to eq trace_fields
    end
  end
end

RSpec.describe Honeycomb::Span do
  let(:libhoney_client) { Libhoney::TestClient.new }
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
