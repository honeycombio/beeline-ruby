# frozen_string_literal: true

if defined?(Honeycomb::Faraday)
  RSpec.describe Honeycomb::Faraday do
    describe "sends basic events" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
        end
      end
      let(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:connection) do
        Faraday.new do |conn|
          conn.use :honeycomb,
                   client: client
          conn.adapter Faraday.default_adapter
        end
      end

      let!(:response) do
        stub_request(:get, "https://www.honeycomb.io")
        connection.get "https://www.honeycomb.io"
      end

      it "has the right url in the response" do
        expect(response.env[:url].to_s).to eq("https://www.honeycomb.io")
      end

      it "sends the right amount of events" do
        expect(libhoney_client.events.size).to eq 1
      end

      let(:event_data) { libhoney_client.events.map(&:data) }

      it_behaves_like "event data"
    end

    describe "supports various initialization methods" do
      let(:current_faraday_version) { Gem::Version.new(Faraday::VERSION) }
      let(:include_http_adapter) do
        Gem::Dependency.new("", "~> 0").match?("", current_faraday_version)
      end

      it "supports standard usage with no block" do
        f = Faraday.new("http://honeycomb.io")
        expected = [
          Faraday::Request::UrlEncoded,
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end

      it "supports providing a builder with a string key" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new("builder" => stack)

        expected = [
          Faraday::Request::Retry,
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end

      it "supports providing a builder with a symbol key" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)

        expected = [
          Faraday::Request::Retry,
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end

      it "supports providing a builder that only has an adapter" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)

        expected = [
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end

      it "supports providing a builder and a url" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new("https://example.com", builder: stack)

        expected = [
          Faraday::Request::Retry,
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end

      it "does not add honeycomb middleware if it is not needed" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)
        # force the builder to lock the middleware stack
        f.builder.app

        expected = [
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)

        f2 = Faraday.new(builder: stack)
        # force the builder to lock the middleware stack
        f2.builder.app

        expected = [
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f2.builder.handlers).to eq(expected)
      end

      it "supports providing a builder and a block" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.response :logger
        end
        f = Faraday.new(builder: stack) do |faraday|
          faraday.request  :url_encoded
          faraday.adapter Faraday.default_adapter
        end

        expected = [
          Faraday::Response::Logger,
          Faraday::Request::UrlEncoded,
          Honeycomb::Faraday,
        ]

        include_http_adapter && expected << Faraday::Adapter::NetHttp

        expect(f.builder.handlers).to eq(expected)
      end
    end

    describe "supports not having a honeycomb client instance" do
      class DummyMiddleware
        def initialize(app)
          @app = app
        end

        def call(env)
          @app.call(env)
        end
      end

      let(:connection) do
        Faraday.new do |conn|
          conn.use :honeycomb, client: nil
          conn.use DummyMiddleware
          conn.adapter Faraday.default_adapter
        end
      end

      let(:response) do
        stub_request(:get, "https://www.honeycomb.io")
        connection.get "https://www.honeycomb.io"
      end

      it "has the right url in the response" do
        expect(response.env[:url].to_s).to eq("https://www.honeycomb.io")
      end

      it "continues to call middleware" do
        expect_any_instance_of(DummyMiddleware).to receive(:call)
        expect(response).to be_nil
      end
    end
  end
end
