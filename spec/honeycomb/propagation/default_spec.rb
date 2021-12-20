# frozen_string_literal: true

require "honeycomb/propagation/default"

RSpec.describe Honeycomb::DefaultPropagation::UnmarshalTraceContext do
  let(:parent_id) { SecureRandom.hex(8) }
  let(:dataset) { "dataset" }
  let(:trace_id) { SecureRandom.hex(16) }
  let(:builder) { instance_double("Builder", dataset: dataset) }
  let(:fields) { {} }
  let(:trace) { instance_double("Trace", id: trace_id, fields: fields) }

  let(:honeycomb_span) do
    instance_double("Span", id: parent_id, trace: trace, builder: builder)
      .extend(Honeycomb::PropagationSerializer)
  end

  let(:w3c_span) do
    instance_double("Span", id: parent_id, trace: trace, builder: builder)
      .extend(Honeycomb::W3CPropagation::MarshalTraceContext)
  end

  let(:default_propagation) { Class.new.extend(described_class) }

  describe "handles an incoming span from a Honeycomb trace" do
    let(:fields) do
      { "test" => "honeycomb" }
    end

    let(:rack_env) do
      { "HTTP_X_HONEYCOMB_TRACE" => honeycomb_span.to_trace_header }
    end
    let(:output) do
      default_propagation.parse_rack_env(rack_env)
    end

    it "produces the correct trace_id" do
      expect(output[0]).to eq trace_id
    end

    it "produces the correct parent_span_id" do
      expect(output[1]).to eq parent_id
    end

    it "produces the correct fields" do
      expect(output[2]).to eq fields
    end

    it "produces the correct dataset" do
      expect(output[3]).to eq dataset
    end
  end

  describe "handles an incoming span from a W3C trace" do
    let(:rack_env) do
      { "HTTP_TRACEPARENT" => w3c_span.to_trace_header }
    end
    let(:output) do
      default_propagation.parse_rack_env(rack_env)
    end

    it "produces the correct trace_id" do
      expect(output[0]).to eq trace_id
    end

    it "produces the correct parent_span_id" do
      expect(output[1]).to eq parent_id
    end

    it "returns nil fields" do
      expect(output[2]).to eq nil
    end

    it "returns nil dataset" do
      expect(output[3]).to eq nil
    end
  end

  describe "prefers Honeycomb trace header over W3C when both are present" do
    let(:fields) do
      { "test" => "honeycomb" }
    end

    let(:rack_env) do
      { "HTTP_X_HONEYCOMB_TRACE" => honeycomb_span.to_trace_header,
        "HTTP_TRACEPARENT" => w3c_span.to_trace_header }
    end
    let(:output) do
      default_propagation.parse_rack_env(rack_env)
    end

    it "produces the correct trace_id" do
      expect(output[0]).to eq trace_id
    end

    it "produces the correct parent_span_id" do
      expect(output[1]).to eq parent_id
    end

    it "produces the correct fields" do
      expect(output[2]).to eq fields
    end

    it "produces the correct dataset" do
      expect(output[3]).to eq dataset
    end
  end
end
