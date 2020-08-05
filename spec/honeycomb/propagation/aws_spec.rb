# frozen_string_literal: true

require "securerandom"
require "honeycomb/propagation/aws"

RSpec.describe Honeycomb::AWSPropagation::UnmarshalTraceContext do
  let(:aws_propagation) { Class.new.extend(subject) }

  it "handles a nil trace" do
    expect(aws_propagation.parse(nil)).to eq [nil, nil, nil, nil]
  end

  it "handles invalid string" do
    expect(aws_propagation.parse("test")).to eq [nil, nil, nil, nil]
  end

  it "handles only having trace id being specified" do
    expect(aws_propagation.parse("Root=root")).to eq ["root", "root", nil, nil]
  end

  it "handles no trace id being specified" do
    expect(aws_propagation.parse("Parent=1")).to eq [nil, nil, nil, nil]
  end

  it "handles having root and parent specified" do
    serialized_trace =
      "Root=root;Parent=parent"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "parent",
      nil,
      nil,
    ]
  end

  it "handles having root and self specified" do
    serialized_trace =
      "Root=root;Self=self"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      nil,
      nil,
    ]
  end

  it "handles having root, self, and parent specified, self should win" do
    serialized_trace =
      "Root=root;Parent=parent;Self=self"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      nil,
      nil,
    ]
  end

  it "handles having root, self, and parent specified, unordered, self wins" do
    serialized_trace =
      "Self=self;Parent=parent;Root=root"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      nil,
      nil,
    ]
  end

  it "handles with case insensitivity" do
    serialized_trace =
      "self=self;parent=parent;root=root"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      nil,
      nil,
    ]
  end

  it "handles parsing a context" do
    serialized_trace =
      "Root=root;Self=self;userID=1;test=true"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      { "test" => "true", "userID" => "1" },
      nil,
    ]
  end

  it "handles bad formating in trace fields" do
    serialized_trace =
      "Root=root;Self=self;userID=1;=true"
    expect(aws_propagation.parse(serialized_trace)).to eq [
      "root",
      "self",
      { "userID" => "1" },
      nil,
    ]
  end
end

RSpec.describe Honeycomb::AWSPropagation::MarshalTraceContext do
  let(:builder) { instance_double("Builder", dataset: "rails") }
  let(:trace) { instance_double("Trace", id: 2, fields: {}) }
  let(:span) do
    instance_double("Span", id: 1, trace: trace, builder: builder)
      .extend(subject)
  end

  it "can serialize a basic span" do
    expect(span.to_trace_header)
      .to eq("Root=2;Parent=1")
  end
end

RSpec.describe "Propagation" do
  let(:parent_id) { SecureRandom.hex(8) }
  let(:dataset) { "dataset" }
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
      .extend(Honeycomb::AWSPropagation::MarshalTraceContext)
  end

  let(:aws_propagation) do
    Class.new.extend(Honeycomb::AWSPropagation::UnmarshalTraceContext)
  end

  let(:output) do
    aws_propagation.parse(span.to_trace_header)
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

  it "produces the correct fields" do
    expect(output[2]).to eq fields
  end
end
