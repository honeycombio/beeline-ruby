# frozen_string_literal: true

require "rack"
require "honeycomb/integrations/warden"

module Honeycomb
  # Rack specific methods for building middleware
  module Rack
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

    attr_reader :app, :client

    def initialize(app, client:)
      @app = app
      @client = client
    end

    def call(env)
      hny = env["HTTP_X_HONEYCOMB_TRACE"]
      client.start_span(name: "http_request", serialized_trace: hny) do |span|
        add_field = lambda do |key, value|
          next unless value && !value.empty?

          span.add_field(key, value)
        end

        extract_fields(env, RACK_FIELDS, &add_field)

        status, headers, body = app.call(env)

        add_package_information(env, &add_field)

        extract_user_information(env, &add_field)

        span.add_field("response.status_code", status)

        [status, headers, body]
      end
    end

    def add_package_information(_env)
      yield "meta.package", "rack"
      yield "meta.package_version", ::Rack::VERSION.join(".")
    end

    def extract_fields(env, fields)
      fields.each do |key, value|
        yield value, env[key]
      end
    end

    # Rack middleware
    class Middleware
      include Rack
      include Warden
    end
  end
end
