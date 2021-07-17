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
    configuration.presend_hook do
    end
    configuration.sample_hook do
    end
    configuration.http_trace_parser_hook do
    end
    configuration.http_trace_propagation_hook do
    end
  end

  it "has a presend_hook" do
    expect(configuration.presend_hook).to respond_to(:call)
  end

  it "has a sample_hook" do
    expect(configuration.sample_hook).to respond_to(:call)
  end

  it "has a http_trace_parser_hook" do
    expect(configuration.http_trace_parser_hook).to respond_to(:call)
  end

  it "has a http_trace_propagation_hook" do
    expect(configuration.http_trace_propagation_hook).to respond_to(:call)
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

  describe "error_backtrace_limit" do
    it "defaults to 0" do
      expect(configuration.error_backtrace_limit).to eq(0)
    end

    context "configured" do
      it "uses the provided number" do
        configuration.error_backtrace_limit = 3

        expect(configuration.error_backtrace_limit).to eq(3)
      end

      it "raises an error for a non-number" do
        expect do
          configuration.error_backtrace_limit = nil
        end.to raise_error(TypeError)
      end
    end
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
