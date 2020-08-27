# frozen_string_literal: true

require "securerandom"
require "honeycomb/propagation/w3c"

RSpec.describe Honeycomb::W3CPropagation::UnmarshalTraceContext do
  let(:w3c_propagation) { Class.new.extend(subject) }

  it "handles a nil trace" do
    expect(w3c_propagation.parse(nil)).to eq [nil, nil, nil, nil]
  end

  it "handles invalid string" do
    expect(w3c_propagation.parse("test")).to eq [nil, nil, nil, nil]
  end

  it "handles a standard w3c traceparent" do
    expect(w3c_propagation
      .parse("00-7f042f75651d9782dcff93a45fa99be0-c998e73e5420f609-01")).to eq [
        "7f042f75651d9782dcff93a45fa99be0",
        "c998e73e5420f609",
        nil,
        nil,
      ]
  end

  it "handles an unsupported version" do
    expect(w3c_propagation
      .parse("999-7f042f75651d9782dcff93a45fa99be0-c998e73e5420f609-01"))
      .to eq [
        nil, nil, nil, nil
      ]
  end

  it "handles an invalid trace id" do
    expect(w3c_propagation
      .parse("00-00000000000000000000000000000000-c998e73e5420f609-01")).to eq [
        nil, nil, nil, nil
      ]
  end

  it "handles an invalid parent span id" do
    expect(w3c_propagation
      .parse("00-7f042f75651d9782dcff93a45fa99be0-0000000000000000-01")).to eq [
        nil, nil, nil, nil
      ]
  end

  it "handles a missing trace id" do
    expect(w3c_propagation
      .parse("00-c998e73e5420f609-01")).to eq [
        nil, nil, nil, nil
      ]
  end

  it "handles a missing parent span id" do
    expect(w3c_propagation
      .parse("00-7f042f75651d9782dcff93a45fa99be0-01")).to eq [
        nil, nil, nil, nil
      ]
  end
end

RSpec.describe Honeycomb::W3CPropagation::MarshalTraceContext do
  let(:parent_id) { SecureRandom.hex(8) }
  let(:trace_id) { SecureRandom.hex(16) }
  let(:builder) { instance_double("Builder", dataset: "rails") }
  let(:trace) { instance_double("Trace", id: trace_id, fields: {}) }
  let(:span) do
    instance_double("Span", id: parent_id, trace: trace, builder: builder)
      .extend(subject)
  end

  it "can serialize a basic span" do
    expect(span.to_trace_header)
      .to eq("00-#{trace_id}-#{parent_id}-01")
  end
end

RSpec.describe "Propagation" do
  let(:parent_id) { SecureRandom.hex(8) }
  let(:dataset) { "dataset" }
  let(:trace_id) { SecureRandom.hex(16) }
  let(:builder) { instance_double("Builder", dataset: dataset) }
  let(:trace) { instance_double("Trace", id: trace_id, fields: {}) }
  let(:span) do
    instance_double("Span", id: parent_id, trace: trace, builder: builder)
      .extend(Honeycomb::W3CPropagation::MarshalTraceContext)
  end

  let(:w3c_propagation) do
    Class.new.extend(Honeycomb::W3CPropagation::UnmarshalTraceContext)
  end

  let(:output) do
    w3c_propagation.parse(span.to_trace_header)
  end

  it "returns nil dataset" do
    expect(output[3]).to eq nil
  end

  it "produces the correct trace_id" do
    expect(output[0]).to eq trace_id
  end

  it "produces the correct parent_span_id" do
    expect(output[1]).to eq parent_id
  end
end
