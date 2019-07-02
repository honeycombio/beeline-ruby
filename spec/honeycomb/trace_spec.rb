# frozen_string_literal: true

require "libhoney"

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
