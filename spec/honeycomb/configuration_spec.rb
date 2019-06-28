# frozen_string_literal: true

RSpec.describe Honeycomb::Configuration do
  let(:configuration) { Honeycomb::Configuration.new }
  let(:dataset_name) { "dataset" }
  let(:service_name) { "service_name" }
  let(:write_key) { "service_name" }
  let(:api_host) { "https://www.honeycomb.io" }
  let(:event) { configuration.client.event }

  before do
    configuration.write_key = write_key
    configuration.dataset = dataset_name
    configuration.api_host = api_host
  end

  it "has a default service_name" do
    expect(configuration.service_name).to eq dataset_name
  end

  it "has the correct write_key" do
    expect(configuration.write_key).to eq write_key
  end

  it "has the correct dataset" do
    expect(configuration.dataset).to eq dataset_name
  end

  it "has the correct api_host" do
    expect(configuration.api_host).to eq api_host
  end

  it "has a client that is the correct type" do
    expect(configuration.client).to be_a Libhoney::Client
  end

  it "configures the client with the correct write_key" do
    expect(event.writekey).to be write_key
  end

  it "configures the client with the correct dataset" do
    expect(event.dataset).to be dataset_name
  end

  it "configures the client with the correct api_host" do
    expect(event.api_host).to be api_host
  end

  describe "configured service_name" do
    before do
      configuration.service_name = service_name
    end

    it "uses the provided service_name" do
      expect(configuration.service_name).to eq service_name
    end
  end
end
