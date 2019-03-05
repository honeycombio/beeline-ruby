# frozen_string_literal: true

module Honeycomb
  # Automatically capture rack requests and create a trace
  class Rack
    attr_reader :app, :client

    def initialize(app, client:)
      @app = app
      @client = client
    end

    def call(env)
      client.start_span(name: "http_request") do |span|
        # generic rack fields
        add_env_field(span, env, "REQUEST_METHOD", "request.method")
        add_env_field(span, env, "PATH_INFO", "request.path")
        add_env_field(span, env, "rack.url_scheme", "request.protocol")
        add_env_field(span, env, "QUERY_STRING", "request.query_string")
        add_env_field(span, env, "HTTP_VERSION", "request.http_version")
        add_env_field(span, env, "HTTP_HOST", "request.host")
        add_env_field(span, env, "REMOTE_ADDR", "request.remote_addr")
        add_env_field(span, env, "HTTP_USER_AGENT", "request.header.user_agent")

        # sinatra specific fields
        add_env_field(span, env, "sinatra.route", "request.route")

        status, headers, body = app.call(env)

        span.add_field("response.status_code", status)

        [status, headers, body]
      end
    end

    private

    def add_env_field(span, env, env_key, key)
      env_value = env[env_key]

      return unless env_value && !env_value.empty?

      span.add_field(key, env_value)
    end
  end
end
