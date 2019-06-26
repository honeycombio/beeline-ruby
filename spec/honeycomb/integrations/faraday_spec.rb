# frozen_string_literal: true

if defined?(Honeycomb::Faraday)
  RSpec.describe Honeycomb::Faraday do
    describe "sends basic events" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:connection) do
        Faraday.new do |conn|
          conn.use :honeycomb,
                   client: Honeycomb::Client.new(client: libhoney_client)
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
      it "supports standard usage with no block" do
        f = Faraday.new("http://honeycomb.io")
        expect(f.builder.handlers).to eq([
                                           Faraday::Request::UrlEncoded,
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end

      it "supports providing a builder with a string key" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new("builder" => stack)

        expect(f.builder.handlers).to eq([
                                           Faraday::Request::Retry,
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end

      it "supports providing a builder with a symbol key" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)

        expect(f.builder.handlers).to eq([
                                           Faraday::Request::Retry,
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end

      it "supports providing a builder that only has an adapter" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)

        expect(f.builder.handlers).to eq([
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end

      it "supports providing a builder and a url" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.request :retry
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new("https://example.com", builder: stack)

        expect(f.builder.handlers).to eq([
                                           Faraday::Request::Retry,
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end

      it "does not add honeycomb middleware if it is not needed" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.adapter Faraday.default_adapter
        end
        f = Faraday.new(builder: stack)
        # force the builder to lock the middleware stack
        f.builder.app

        expect(f.builder.handlers).to eq([
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])

        f2 = Faraday.new(builder: stack)
        # force the builder to lock the middleware stack
        f2.builder.app

        expect(f2.builder.handlers).to eq([
                                            Honeycomb::Faraday,
                                            Faraday::Adapter::NetHttp,
                                          ])
      end

      it "supports providing a builder and a block" do
        stack = Faraday::RackBuilder.new do |builder|
          builder.response :logger
        end
        f = Faraday.new(builder: stack) do |faraday|
          faraday.request  :url_encoded
          faraday.adapter Faraday.default_adapter
        end

        expect(f.builder.handlers).to eq([
                                           Faraday::Response::Logger,
                                           Faraday::Request::UrlEncoded,
                                           Honeycomb::Faraday,
                                           Faraday::Adapter::NetHttp,
                                         ])
      end
    end
  end
end
