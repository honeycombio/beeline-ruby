# frozen_string_literal: true

require "faraday"

module Honeycomb
  # Faraday middleware to create spans around outgoing http requests
  class Faraday < ::Faraday::Middleware
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

::Faraday::Connection.module_eval do
  alias_method :standard_initialize, :initialize

  def initialize(url = nil, options = nil, &block)
    standard_initialize(url, options, &block)

    return if @builder.handlers.include? Honeycomb::Faraday

    # if the honeycomb faraday middleware has not been added by the user then
    # add it here using the global honeycomb client
    @builder.insert(0, Honeycomb::Faraday, client: Honeycomb.client)
  end
end

Faraday::Middleware.register_middleware honeycomb: -> { Honeycomb::Faraday }
