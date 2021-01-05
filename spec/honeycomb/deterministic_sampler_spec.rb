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
  include_examples "sampling distribution", 10, 0.06
end

RSpec.describe Honeycomb::DeterministicSampler do
  subject { Class.new.include(described_class).new }

  EXPECTED_SAMPLES = [
    ["4YeYygWjTZ41zOBKUoYUaSVxPGm78rdU", false],
    ["iow4KAFBl9u6lF4EYIcsFz60rXGvu7ph", true],
    ["EgQMHtruEfqaqQqRs5nwaDXsegFGmB5n", true],
    ["UnVVepVdyGIiwkHwofyva349tVu8QSDn", true],
    ["rWuxi2uZmBEprBBpxLLFcKtXHA8bQkvJ", true],
    ["8PV5LN1IGm5T0ZVIaakb218NvTEABNZz", false],
    ["EMSmscnxwfrkKd1s3hOJ9bL4zqT1uud5", true],
    ["YiLx0WGJrQAge2cVoAcCscDDVidbH4uE", true],
    ["IjD0JHdQdDTwKusrbuiRO4NlFzbPotvg", false],
    ["ADwiQogJGOS4X8dfIcidcfdT9fY2WpHC", false],
    ["DyGaS7rfQsMX0E6TD9yORqx7kJgUYvNR", true],
    ["MjOCkn11liCYZspTAhdULMEfWJGMHvpK", false],
    ["wtGa41YcFMR5CBNr79lTfRAFi6Vhr6UF", true],
    ["3AsMjnpTBawWv2AAPDxLjdxx4QYl9XXb", false],
    ["sa2uMVNPiZLK52zzxlakCUXLaRNXddBz", false],
    ["NYH9lkdbvXsiUFKwJtjSkQ1RzpHwWloK", false],
    ["8AwzQeY5cudY8YUhwxm3UEP7Oos61RTY", false],
    ["ADKWL3p5gloRYO3ptarTCbWUHo5JZi3j", false],
    ["UAnMARj5x7hkh9kwBiNRfs5aYDsbHKpw", true],
    ["Aes1rgTLMNnlCkb9s6bH7iT5CbZTdxUw", true],
    ["eh1LYTOfgISrZ54B7JbldEpvqVur57tv", false],
    ["u5A1wEYax1kD9HBeIjwyNAoubDreCsZ6", false],
    ["mv70SFwpAOHRZt4dmuw5n2lAsM1lOrcx", true],
    ["i4nIu0VZMuh5hLrUm9w2kqNxcfYY7Y3a", true],
    ["UqfewK2qFZqfJ619RKkRiZeYtO21ngX1", false],
  ].freeze

  EXPECTED_SAMPLES.each do |id, sample|
    it "produces the expected sampling decision" do
      expect(subject.should_sample(2, id)).to eq sample
    end
  end
end
