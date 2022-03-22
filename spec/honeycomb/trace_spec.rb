# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb::Trace do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  let(:presend_hook) { proc {} }
  let(:sample_hook) { proc {} }

  it "passes the hooks to the root span" do
    expect(Honeycomb::Span)
      .to receive(:new)
      .with(hash_including(
              presend_hook: presend_hook,
              sample_hook: sample_hook,
            ))
      .and_call_original

    expect(context).not_to be_nil

    Honeycomb::Trace.new(
      builder: builder,
      context: context,
      presend_hook: presend_hook,
      sample_hook: sample_hook,
    )
  end
end

RSpec.describe Honeycomb::Trace do
  let(:libhoney_client) { Libhoney::TestClient.new(dataset: "awesome") }
  let(:builder) { libhoney_client.builder }

  subject(:trace) do
    Honeycomb::Trace.new(builder: builder,
                         context: Honeycomb::Context.new)
  end

  let(:trace_fields) { { "wow" => 420 } }
  let(:upstream_trace_header) { trace.root_span.to_trace_header }

  let(:distributed_trace) do
    Honeycomb::Trace.new(builder: Libhoney::TestClient.new(dataset: "awesome squared").builder,
                         context: context,
                         serialized_trace: upstream_trace_header)
  end

  before do
    trace_fields.each do |key, value|
      trace.add_field key, value
    end
  end

  it_behaves_like "a tracing object"

  describe "distributed tracing" do
    describe "with a classic key" do
      let(:context) { Honeycomb::Context.new.tap { |c| c.classic = true } }

      it "context should be classic" do
        expect(context.classic?).to be true
      end

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

      it "uses the dataset specified by the trace header" do
        root_span = distributed_trace.root_span
        builder = root_span.instance_variable_get("@builder")
        expect(builder.dataset).to eq "awesome"
      end
    end

    describe "with a modern key" do
      let(:context) { Honeycomb::Context.new.tap { |c| c.classic = false } }
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

      it "ignores the dataset in the trace header and uses the dataset configured for the client" do
        root_span = distributed_trace.root_span
        builder = root_span.instance_variable_get("@builder")
        expect(builder.dataset).to eq "awesome squared"
      end
    end
  end
end

RSpec.describe Honeycomb::Trace do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  let(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }
  let(:serialized_trace) { trace.root_span.to_trace_header }
  let(:parser_hook) do
    double("parser_hook").tap do |hook|
      allow(hook).to receive(:call)
    end
  end
  subject(:distributed_trace) do
    Honeycomb::Trace.new(builder: builder,
                         context: context,
                         parser_hook: parser_hook,
                         serialized_trace: serialized_trace)
  end

  it "should have the attributes provided by the serialized_trace" do
    expect(distributed_trace).to have_attributes(id: trace.id)
  end
end
