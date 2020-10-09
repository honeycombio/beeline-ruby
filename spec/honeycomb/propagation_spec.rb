# frozen_string_literal: true

require "securerandom"
require "honeycomb/propagation"

RSpec.describe Honeycomb::PropagationParser do
  let(:propagation) { Class.new.extend(subject) }

  it "handles a nil trace" do
    expect(propagation.parse(nil)).to eq [nil, nil, nil, nil]
  end

  it "handles invalid string" do
    expect(propagation.parse("test")).to eq [nil, nil, nil, nil]
  end

  it "handles only having trace id being specified" do
    expect(propagation.parse("1;trace_id=1")).to eq [nil, nil, nil, nil]
  end

  it "handles only having parent span id being specified" do
    expect(propagation.parse("1;parent_id=1")).to eq [nil, nil, nil, nil]
  end

  it "handles having trace and parent id specified" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id"
    expect(propagation.parse(serialized_trace)).to eq [
      "trace_id",
      "parent_id",
      nil,
      nil,
    ]
  end

  it "handles a dataset" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id,dataset=dataset"
    expect(propagation.parse(serialized_trace)).to eq [
      "trace_id",
      "parent_id",
      nil,
      "dataset",
    ]
  end

  it "handles parsing a context" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id,context=eyJ0ZXN0IjoxfQ=="
    expect(propagation.parse(serialized_trace)).to eq [
      "trace_id",
      "parent_id",
      { "test" => 1 },
      nil,
    ]
  end

  it "handles invalid json" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id,context=dGVzdA=="
    expect(propagation.parse(serialized_trace)).to eq [
      "trace_id",
      "parent_id",
      {},
      nil,
    ]
  end
end

RSpec.describe Honeycomb::PropagationSerializer do
  let(:builder) { instance_double("Builder", dataset: "rails") }
  let(:trace) { instance_double("Trace", id: 2, fields: {}) }
  let(:span) do
    instance_double("Span", id: 1, trace: trace, builder: builder)
      .extend(subject)
  end

  it "can serialize a basic span" do
    expect(span.to_trace_header)
      .to eq("1;dataset=rails,trace_id=2,parent_id=1,context=e30=")
  end
end

RSpec.describe "Propagation" do
  let(:parent_id) { SecureRandom.hex(8) }
  let(:dataset) { "rails,tesing/with-%characters%" }
  let(:trace_id) { SecureRandom.hex(16) }
  let(:fields) do
    {
      "test" => "honeycomb",
    }
  end
  let(:builder) { instance_double("Builder", dataset: dataset) }
  let(:trace) { instance_double("Trace", id: trace_id, fields: fields) }
  let(:span) do
    instance_double("Span", id: parent_id, trace: trace, builder: builder)
      .extend(Honeycomb::PropagationSerializer)
  end

  let(:propagation) { Class.new.extend(Honeycomb::PropagationParser) }

  let(:output) do
    propagation.parse(span.to_trace_header)
  end

  it "produces the correct dataset" do
    expect(output[3]).to eq dataset
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
end
