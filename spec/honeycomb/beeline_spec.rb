# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb do
  let(:libhoney_client) { Libhoney::TestClient.new }

  before do
    Honeycomb.configure do |config|
      config.write_key = "write_key"
      config.dataset = "dataset"
      config.service_name = "service_name"
      config.client = libhoney_client
    end
  end

  describe "when using a block" do
    before do
      Honeycomb.start_span(name: "test") do
      end
    end

    it "sends the right amount of events" do
      expect(libhoney_client.events.size).to eq 1
    end
  end

  describe "manually sending" do
    before do
      span = Honeycomb.start_span(name: "test")
      span.send
    end

    it "sends the right amount of events" do
      expect(libhoney_client.events.size).to eq 1
    end
  end

  describe "adding fields to span" do
    before do
      Honeycomb.start_span(name: "test") do
        Honeycomb.add_field("interesting", "banana")
        Honeycomb.add_field("fascinating", "apple", namespace: "hmm")
        Honeycomb.add_field("captivating", "orange", namespace: nil)
      end
    end

    it "contains the expected fields" do
      fields = {
        "app.interesting" => "banana",
        "hmm.fascinating" => "apple",
        "captivating" => "orange",
      }
      expect(libhoney_client.events.map(&:data)).to all(include(fields))
    end
  end

  describe "adding fields to trace" do
    before do
      Honeycomb.start_span(name: "test") do
        Honeycomb.add_field_to_trace("interesting", "banana")
        Honeycomb.add_field_to_trace("fascinating", "apple", namespace: "hmm")
        Honeycomb.add_field_to_trace("captivating", "orange", namespace: nil)
      end
    end

    it "contains the expected fields" do
      fields = {
        "app.interesting" => "banana",
        "hmm.fascinating" => "apple",
        "captivating" => "orange",
      }
      expect(libhoney_client.events.map(&:data)).to all(include(fields))
    end
  end
end

RSpec.describe Honeycomb::Beeline do
  it "has a version number" do
    expect(Honeycomb::Beeline::VERSION).not_to be nil
  end
end
