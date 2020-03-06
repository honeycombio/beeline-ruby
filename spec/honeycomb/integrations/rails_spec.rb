# frozen_string_literal: true

if defined?(Honeycomb::Rails)
  require "logger"
  require "rack/test"
  require "rails"
  require "action_controller/railtie"

  RSpec.describe Honeycomb::Rails do
    VERSION = Gem::Version.new(::Rails::VERSION::STRING)
    include Rack::Test::Methods

    # These headers are required for the HTTP fields from the Rack integration.
    #
    # In order to use the shared examples for event data with HTTP fields
    # included, these headers have to be present. Additionally, every request
    # made in this suite has to include a query string, so we just tack on
    # `?honey=bee` to everything.
    before do
      header "Http-Version", "HTTP/1.0"
      header "User-Agent", "RackSpec"
      header "Content-Type", "application/json"
      header "Accept", "application/json"
    end

    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }
    let(:app) do
      Class.new(Rails::Application).tap do |app|
        app.config.logger = Logger.new(STDERR)
        app.config.log_level = :fatal
        app.config.eager_load = false
        app.config.secret_key_base = "3b7cd727ee24e8444053437c36cc66c4"
        app.config.respond_to?(:hosts) && app.config.hosts << "example.org"
        app.config.middleware.insert_before(
          ::Rails::Rack::Logger,
          Honeycomb::Rails::Middleware,
          client: client,
        )
        app.initialize!

        app.routes.draw do
          get "/hello/:name" => "test#hello"
        end
      end
    end

    class TestController < ActionController::Base
      def hello
        render plain: "Hello #{params[:name]}!"
      end
    end

    shared_examples_for "the rails integration" do
      let(:event_data) { libhoney_client.events.map(&:data) }

      it_behaves_like "event data", http_fields: true

      it "sends the right number of events" do
        expect(libhoney_client.events.size).to eq 1
      end

      let(:event) { event_data.first }

      it "sends the right request.controller" do
        expect(event["request.controller"]).to eq controller
      end

      it "sends the right request.action" do
        expect(event["request.action"]).to eq action
      end

      it "sends the right request.route" do
        expect(event["request.route"]).to eq route
      end
    end

    describe "a standard request" do
      before do
        get "/hello/world?honey=bee"
      end

      it "returns ok" do
        expect(last_response).to be_ok
      end

      include_examples "the rails integration" do
        let(:controller) { "test" }
        let(:action) { "hello" }
        let(:route) { "GET /hello/:name(.:format)" }
      end
    end

    describe "a request with invalid parameter encoding" do
      before do
        get "/hello/world?via=%c1&honey=bee"
      end

      if VERSION >= Gem::Version.new("5")
        it "returns bad request" do
          expect(last_response).to be_bad_request
        end
      else
        it "returns ok" do
          expect(last_response).to be_ok
        end
      end

      include_examples "the rails integration" do
        let(:controller) { "test" }
        let(:action) { "hello" }
        let(:route) { "GET /hello/:name(.:format)" }
      end
    end

    describe "an unrecognized request" do
      before do
        get "/unrecognized?action=action&controller=controller&honey=bee"
      end

      it "returns not found" do
        expect(last_response).to be_not_found
      end

      include_examples "the rails integration" do
        let(:controller) { nil }
        let(:action) { nil }
        let(:route) { nil }
      end
    end

    describe "twirp bug" do
      before do
        app.routes.draw do
          mount TwirpBug, at: "/twirp", via: :post
        end
      end

      # Emulates a bug in the twirp gem.
      #
      # The twirp middleware calls IO#read on the rack.input without rewinding.
      # Later, when Rails tries to parse the request parameters by calling
      # IO#read(n) with the content length, we get back nil, which blows up the
      # default JSON MIME type handler.
      #
      # @see https://github.com/honeycombio/beeline-ruby/issues/31
      # @see https://github.com/honeycombio/beeline-ruby/pull/39
      # @see https://github.com/twitchtv/twirp-ruby/blob/c8520030b3e4eb584042b0a8db9ae606a3b6c6f4/lib/twirp/service.rb#L138
      module TwirpBug
        def self.call(env)
          env["rack.input"].read # don't rewind
          ::Rack::Response.new("OK").finish
        end
      end

      before do
        post "/twirp?honey=bee", '{"json":"object"}'
      end

      it "returns ok" do
        expect(last_response).to be_ok
      end

      include_examples "the rails integration" do
        let(:controller) { nil }
        let(:action) { nil }
        let(:route) { "POST /twirp" }
      end
    end
  end
end
