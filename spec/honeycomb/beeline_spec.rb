# frozen_string_literal: true

RSpec.describe Honeycomb::Beeline do
  it "has a version number" do
    expect(Honeycomb::Beeline::VERSION).not_to be nil
  end
end

RSpec.describe Honeycomb::Client do
end

RSpec.describe Honeycomb::Trace do
  subject(:trace) { Honeycomb::Trace.new }
  it "can add fields" do
    trace.add_field("key", "value")
  end

  it "can add rollup fields" do
    trace.add_rollup_field("key", 1)
  end

  it "can be sent" do
    trace.send
  end
end

RSpec.describe Honeycomb::Span do
end
