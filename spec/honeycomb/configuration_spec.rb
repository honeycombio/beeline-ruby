# frozen_string_literal: true

RSpec.describe Honeycomb::Configuration do
  let(:configuration) { Honeycomb::Configuration.new }
  let(:dataset_name) { "dataset" }
  let(:service_name) { "service_name" }
  let(:write_key) { "e38be416d0d68f9ed1e96432ac1a3380" }
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

  it "has a Libhoney client by default" do
    expect(configuration.client).to be_a Libhoney::Client
  end

  it "has a client with Beeline version information in the user agent" do
    libhoney_client = configuration.client
    transmission = libhoney_client.instance_variable_get(:@transmission)
    user_agent = transmission.instance_variable_get(:@user_agent)
    expect(user_agent).to match(Honeycomb::Beeline::USER_AGENT_SUFFIX)
  end

  context "when debug is enabled" do
    before do
      configuration.debug = true
    end

    it "has a logging Libhoney" do
      expect(configuration.client).to be_a Libhoney::LogClient
    end
  end

  context "when a customized Libhoney client is given in the config" do
    before do
      configuration.client = Libhoney::Client.new(
        writekey: "customized!",
        dataset: dataset_name,
        proxy_config: "https://myproxy.example.com:8080",
      )
    end

    it "has the custom Libhoney as its client" do
      expect(configuration.client.writekey).to eq "customized!"
      proxy_config = configuration.client.instance_variable_get(:@proxy_config)
      expect(proxy_config).not_to be_nil
    end

    # This is known current behavior and consistent with what the other
    # Beeline's do. It would be nice for the Beelines to be able to add
    # their version info to  user-instantiated libhoney/transmissions,
    # but that's not part of the libhoney public API at the moment. So
    # this test exists to confirm the current behavior, even if that
    # behavior is more incidental than intentional.
    it "sadly, does not add Beeline version to the client user-agent" do
      custom_client = configuration.client
      transmission = custom_client.instance_variable_get(:@transmission)
      user_agent = transmission.instance_variable_get(:@user_agent)
      expect(user_agent).not_to match(Honeycomb::Beeline::USER_AGENT_SUFFIX)
    end
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

  it "has a classic API key" do
    expect(configuration.is_classic).to eq true
  end

  describe "non-classic API key" do 
    before do
      configuration.write_key = "d68f9ed1e96432ac1a3380"
      configuration.service_name = " my-service "
    end

    it "has a non-classic write key" do
      expect(configuration.is_classic).to eq false
    end
  end
end
