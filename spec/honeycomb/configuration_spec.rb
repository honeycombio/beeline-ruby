# frozen_string_literal: true

RSpec.describe Honeycomb::Configuration do
  let(:configuration) { Honeycomb::Configuration.new }
  let(:write_key) { "not_a_classic_write_key" }
  let(:api_host) { "https://www.honeycomb.io" }
  let(:event) { configuration.client.event }

  before do
    configuration.write_key = write_key
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

  it "has the correct api_host" do
    expect(configuration.api_host).to eq api_host
  end

  it "has the correct write_key" do
    expect(configuration.write_key).to eq write_key
  end

  describe "#classic?" do
    it "is true when no key is set" do
      configuration.write_key = nil
      expect(configuration.classic?).to be true
    end

    it "is true with a classic key" do
      configuration.write_key = "c1a551c000d68f9ed1e96432ac1a3380"
      expect(configuration.classic?).to be true
    end

    it "is false with an E&S key" do
      configuration.write_key = "1234567890123456789012"
      expect(configuration.classic?).to be false
    end
  end

  describe "#service_name" do
    it "returns the default unknown-service:<process_name> when not set" do
      expect(configuration.instance_variable_get(:@service_name)).to be_nil
      # rspec is the expected process name because *this test suite* is rspec
      expect(configuration.service_name).to eq "unknown_service:rspec"
    end

    it "returns a set service name" do
      configuration.service_name = "awesome_sauce"
      expect(configuration.service_name).to eq "awesome_sauce"
    end

    it "does not remove leading/trailing whitespace" do
      configuration.service_name = "    spacey    "
      expect(configuration.service_name).to eq "    spacey    "
    end

    context "with a classic write key" do
      before do
        allow(configuration).to receive(:classic?).and_return(true)
      end

      it "returns the value of dataset when service_name isn't set" do
        expect(configuration.instance_variable_get(:@service_name)).to be_nil

        configuration.dataset = "a_dataset"
        expect(configuration.service_name).to eq "a_dataset"
      end
    end
  end

  describe "#dataset" do
    it "is based on service_name, no longer set directly" do
      configuration.service_name = "the_service_name"
      configuration.dataset = "ignore_me"
      expect(configuration.dataset).to eq "the_service_name"
    end

    it "removes leading/trailing whitespace to confusion in environments" do
      configuration.service_name = "    spacey    "
      expect do
        expect(configuration.dataset).to eq "spacey"
      end.to output("found extra whitespace in service name\n").to_stderr
    end

    context "defaults to 'unknown_service'" do
      it "when service_name is not set" do
        expect(configuration.dataset).to eq "unknown_service"
      end

      it "when service_name starts with but is longer than 'unknown_service'" do
        configuration.service_name = "unknown_service:a_funky_long_process_name"
        expect(configuration.dataset).to eq "unknown_service"
      end

      it "when service_name is only white space" do
        configuration.service_name = "    "
        expect do
          expect(configuration.dataset).to eq "unknown_service"
        end.to output("found extra whitespace in service name\n").to_stderr
      end
    end

    context "with a classic write key" do
      before do
        allow(configuration).to receive(:classic?).and_return(true)
      end

      it "returns whatever dataset has been set" do
        expect(configuration.dataset).to be_nil

        configuration.dataset = "a_dataset"
        expect(configuration.dataset).to eq "a_dataset"
      end
    end
  end

  describe "#client" do
    let(:service_name) { "client_tests" }
    let(:libhoney_client) do
      configuration.service_name = service_name
      configuration.client
    end

    it "has a Libhoney client by default" do
      expect(libhoney_client).to be_a Libhoney::Client
    end

    it "produces with the correct write_key" do
      expect(libhoney_client.event.writekey).to be write_key
    end

    it "configures the client with the correct dataset" do
      expect(libhoney_client.event.dataset).to eq service_name
    end

    it "configures the client with the correct api_host" do
      expect(libhoney_client.event.api_host).to be api_host
    end

    it "has a client with Beeline version information in the user agent" do
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
          dataset: "custom_dataset",
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
end
