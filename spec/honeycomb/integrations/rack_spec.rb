# frozen_string_literal: true

if defined?(Honeycomb::Rack)
  # Rack::Session was moved to a separate gem in Rack v3.0
  if Gem::Version.new(::Rack.release) >= Gem::Version.new("3.0")
    require "rack/session"
  end
  require "rack/test"
  require "warden"

  class AnApp
    def call(env)
      [200, { "content-type" => "text/plain" }, ["Hello world!"]]
    end
  end

  RSpec.describe Honeycomb::Rack do
    include Rack::Test::Methods
    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:event_data) { libhoney_client.events.map(&:data) }
    let(:base_test_app) { AnApp.new }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }
    let(:honeycomb) do
      Honeycomb::Rack::Middleware.new(base_test_app, client: client)
    end
    let(:auth) { Authenticate.new(honeycomb) }
    let(:warden) do
      Warden::Manager.new(auth) do |manager|
        manager.default_strategies :test
      end
    end
    let(:secret) { "honeycombhoneycombhoneycombhoneycombhoneycombhoneycombhoneycombhoneycomb" }
    let(:session) { Rack::Session::Cookie.new(warden, secret: secret) }
    let(:lint) { Rack::Lint.new(session) }
    let(:app) { lint }

    class User
      def id
        1
      end

      def email
        "support@honeycomb.io"
      end

      def name
        "bee"
      end

      def first_name
        "bee_first"
      end

      def last_name
        "bee_last"
      end

      def created_at
        Time.new 2002, 3, 4, 5, 6, 7
      end
    end

    class Authenticate
      def initialize(app)
        @app = app
      end

      def call(env)
        env["warden"].authenticate!
        @app.call(env)
      end
    end

    class TestStrategy < ::Warden::Strategies::Base
      def valid?
        true
      end

      def authenticate!
        success!(User.new)
      end
    end

    before do
      Warden::Strategies.add(:test, TestStrategy)
      header("Http-Version", "HTTP/1.0")
      header("User-Agent", "RackSpec")
      header("Content-Type", "text/html; charset=UTF-8")
      header("Accept", "*/*")
      header("Accept-Encoding", "gzip")
      header("Accept-Language", "*")
      header("X-Forwarded-For", "1.2.3.4")
      header("X-Forwarded-Proto", "https")
      header("X-Forwarded-Port", "8000")
      header("Referer", "https://forever.misspelled.referer.example.com/")
    end

    describe "standard request" do
      before do
        get "/?honey=bee"
      end

      it "returns ok" do
        expect(last_response).to be_ok
      end

      it "sends a single event" do
        expect(libhoney_client.events.size).to eq 1
      end

      it "includes package information" do
        libhoney_client.events.first.tap do |event|
          expect(event.data).to include(
            "meta.package" => "rack",
            "meta.package_version" => ::Rack.release,
          )
        end
      end

      USER_FIELDS = [
        "user.id",
        "user.email",
        "user.name",
        "user.first_name",
        "user.last_name",
        "user.created_at",
      ].freeze
      it_behaves_like "event data",
                      http_fields: true, additional_fields: USER_FIELDS
    end

    describe "trace header request" do
      let(:trace_id) { "trace_id" }
      let(:parent_id) { "parent_id" }
      let(:dataset) { "test_datatset" }

      let(:serialized_trace) do
        "1;trace_id=#{trace_id},parent_id=#{parent_id},dataset=#{dataset}"
      end

      before do
        header("X-Honeycomb-Trace", serialized_trace)
        get "/?honey=bee"
      end

      it "returns ok" do
        expect(last_response).to be_ok
      end

      it "sends a single event" do
        expect(libhoney_client.events.size).to eq 1
      end

      it "has the expected dataset" do
        expect(libhoney_client.events.first.dataset).to eq(dataset)
      end

      it "has the expected fields from the header" do
        libhoney_client.events.first.tap do |event|
          expect(event.data).to include(
            "trace.trace_id" => trace_id,
            "trace.parent_id" => parent_id,
          )
        end
      end

      it_behaves_like "event data", http_fields: true
    end
  end
end
