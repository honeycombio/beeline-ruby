# frozen_string_literal: true

require "faraday"

module Honeycomb
  # Faraday middleware to create spans around outgoing http requests
  class Faraday < Faraday::Middleware
    def initialize(app, client:)
      super(app)
      @client = client
    end

    def call(env)
      @client.start_span(name: nil) do |span|
        span.add_field("type", "http_client")
        span.add_field "request.method", env.method.upcase
        span.add_field "request.protocol", env.url.scheme
        span.add_field "request.host", env.url.host
        span.add_field "request.path", env.url.path
        span.add_field "meta.package", "faraday"
        span.add_field "meta.package_version", ::Faraday::VERSION

        env.request_headers["X-Honeycomb-Trace"] = span.to_trace_header

        @app.call(env).tap do |response|
          span.add_field "response.status_code", response.status
        end
      end
    end
  end
end
