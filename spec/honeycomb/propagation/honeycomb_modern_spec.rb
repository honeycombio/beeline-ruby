# frozen_string_literal: true

require "securerandom"
require "honeycomb/propagation/context"
require "honeycomb/propagation/honeycomb_modern"

RSpec.shared_examples "honeycomb_propagation_parse" do
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

  it "ignores an incoming dataset" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id,dataset=dataset"
    expect(propagation.parse(serialized_trace)).to eq [
      "trace_id",
      "parent_id",
      nil,
      nil,
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

  it "handles parsing a context and ignores incoming dataset" do
    serialized_trace =
      "1;trace_id=trace_id,parent_id=parent_id,context=eyJ0ZXN0IjoxfQ==,dataset=ignoreme"
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

RSpec.describe Honeycomb::HoneycombModernPropagation::UnmarshalTraceContext do
  let(:propagation) { Class.new.extend(subject) }

  describe "module usage" do
    let(:propagation) { Class.new.extend(subject) }
    include_examples "honeycomb_propagation_parse"
  end

  describe "class method usage" do
    let(:propagation) { subject }
    include_examples "honeycomb_propagation_parse"
  end
end

RSpec.describe Honeycomb::HoneycombModernPropagation::MarshalTraceContext do
  describe "module usage" do
    let(:builder) { instance_double("Builder", dataset: "rails") }
    let(:trace) { instance_double("Trace", id: 2, fields: {}) }
    let(:span) do
      instance_double("Span", id: 1, trace: trace, builder: builder)
        .extend(subject)
    end

    it "can serialize a basic span and not include the dataset" do
      expect(span.to_trace_header)
        .to eq("1;trace_id=2,parent_id=1,context=e30=")
    end
  end

  describe "class method usage" do
    let(:context) { Honeycomb::Propagation::Context.new(2, 1, {}, "rails") }

    it "can serialize a basic span and not include the dataset" do
      expect(subject.to_trace_header(context))
        .to eq("1;trace_id=2,parent_id=1,context=e30=")
    end
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
