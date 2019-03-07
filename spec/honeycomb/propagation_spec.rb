# frozen_string_literal: true

require "honeycomb/propagation"

RSpec.describe Honeycomb::Propagation do
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
