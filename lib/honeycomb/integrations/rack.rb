# frozen_string_literal: true

require "rack"

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

    COMMON_USER_FIELDS = %i[
      email
      name
      first_name
      last_name
      created_at
      id
    ].freeze

    SCOPE_PATTERN = /^warden\.user\.([^.]+)\.key$/.freeze

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

    def extract_user_information(env)
      warden = env["warden"]

      return unless warden

      session = env["rack.session"] || {}
      keys = session.keys.select do |key|
        key.match(SCOPE_PATTERN)
      end
      warden_scopes = keys.map do |key|
        key.gsub(SCOPE_PATTERN, "\1")
      end
      best_scope = warden_scopes.include?("user") ? "user" : warden_scopes.first

      return unless best_scope

      env["warden"].user(scope: best_scope, run_callbacks: false).tap do |user|
        COMMON_USER_FIELDS.each do |field|
          user.respond_to?(field) && yield("user.#{field}", user.send(field))
        end
      end
    end
  end
end
