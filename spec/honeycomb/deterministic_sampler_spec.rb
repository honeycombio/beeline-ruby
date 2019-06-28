# frozen_string_literal: true

require "securerandom"
require "honeycomb/deterministic_sampler"

RSpec.shared_examples "specific sampling decision" do |rate, value, decision|
  it "makes the correct sampling decision" do
    expect(subject.should_sample(rate, value)).to eq decision
  end
end

RSpec.shared_examples "sampling distribution" do |sample_rate, margin|
  let(:requests) { 50_000 }

  def random_request_id
    SecureRandom.uuid
  end

  it "gives the correct distribution for sample rate of #{sample_rate}" do
    expected = requests * 1.fdiv(sample_rate)
    bounds = expected * margin
    samples = 0
    requests.times do
      subject.should_sample(sample_rate, random_request_id) && samples += 1
    end
    expect(samples).to be_within(bounds).of(expected)
  end
end

RSpec.describe Honeycomb::DeterministicSampler do
  subject { Class.new.include(described_class).new }

  include_examples "specific sampling decision", 17, "hello", false
  include_examples "specific sampling decision", 17, "hello", false
  include_examples "specific sampling decision", 17, "world", false
  include_examples "specific sampling decision", 17, "this5", true

  include_examples "sampling distribution", 1, 0.05
  include_examples "sampling distribution", 2, 0.05
  include_examples "sampling distribution", 10, 0.05
end
