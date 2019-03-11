# frozen_string_literal: true

module Honeycomb
  # Automatically capture rack requests and create a trace
  class Rack
    RACK_FIELDS = [
      ["REQUEST_METHOD", "request.method"],
      ["PATH_INFO", "request.path"],
      ["QUERY_STRING", "request.query_string"],
      ["HTTP_VERSION", "request.http_version"],
      ["HTTP_HOST", "request.host"],
      ["REMOTE_ADDR", "request.remote_addr"],
      ["HTTP_USER_AGENT", "request.header.user_agent"],
      ["rack.url_scheme", "request.protocol"],
    ].freeze

    SINATRA_FIELDS = [
      ["sinatra.route", "request.route"],
    ].freeze

    attr_reader :app, :client

    def initialize(app, client:)
      @app = app
      @client = client
    end

    def call(env)
      hny = env["HTTP_X_HONEYCOMB_TRACE"]
      client.start_span(name: "http_request", serialized_trace: hny) do |span|
        add_env_field = lambda do |(env_key, key)|
          env_value = env[env_key]
          next unless env_value && !env_value.empty?

          span.add_field(key, env_value)
        end

        if defined?(::Rails::VERSION::STRING)
          span.add_field("meta.package", "rails")
          span.add_field("meta.package_version", ::Rails::VERSION::STRING)
        elsif defined?(::Sinatra::VERSION)
          span.add_field("meta.package", "sinatra")
          span.add_field("meta.package_version", ::Sinatra::VERSION)
        elsif defined?(::Rack::VERSION)
          span.add_field("meta.package", "rack")
          span.add_field("meta.package_version", ::Rack::VERSION.join("."))
        end

        RACK_FIELDS.each(&add_env_field)

        status, headers, body = app.call(env)

        # this is populated after the action is executed
        SINATRA_FIELDS.each(&add_env_field)

        span.add_field("response.status_code", status)

        [status, headers, body]
      end
    end
  end
end
