# frozen_string_literal: true

if defined?(Honeycomb::Rack)
  require "rack/test"
  require "rack/lobster"
  require "warden"

  RSpec.describe Honeycomb::Rack do
    include Rack::Test::Methods
    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:event_data) { libhoney_client.events.map(&:data) }
    let(:lobster) { Rack::Lobster.new }
    let(:client) { Honeycomb::Client.new(client: libhoney_client) }
    let(:honeycomb) do
      Honeycomb::Rack.new(lobster, client: client)
    end
    let(:auth) { Authenticate.new(honeycomb) }
    let(:warden) do
      Warden::Manager.new(auth) do |manager|
        manager.default_strategies :test
      end
    end
    let(:session) { Rack::Session::Cookie.new(warden, secret: "honeycomb") }
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
        Time.now
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

      it_behaves_like "event data", http_fields: true
    end

    describe "trace header request" do
      let(:serialized_trace) do
        "1;trace_id=wow,parent_id=eep,dataset=test_dataset"
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

      it_behaves_like "event data", http_fields: true
    end
  end
end
