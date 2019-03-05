# frozen_string_literal: true

require "socket"
require "forwardable"
require "honeycomb/beeline/version"
require "honeycomb/context"

module Honeycomb
  # The Honeycomb Beeline client
  class Client
    extend Forwardable

    def initialize(client:)
      client.add_field "meta.beeline_version", Honeycomb::Beeline::VERSION
      client.add_field "meta.local_hostname", host_name
      @client = client
      @context = Context.new

      at_exit do
        client.close
      end
    end

    def start_span(name:)
      return unless block_given?

      if context.current_trace.nil?
        Trace.new(builder: client.builder, context: context)
      else
        context.current_span.create_child
      end

      context.current_span.add_field("name", name)

      begin
        yield context.current_span
      rescue StandardError => e
        context.current_span.add_field("request.error", e.class.name)
        context.current_span.add_field("request.error_detail", e.message)
        raise e
      ensure
        context.current_span.send
      end
    end

    def add_field(key, value)
      return if context.current_span.nil?

      context.current_span.add_field("app.#{key}", value)
    end

    def add_field_to_trace(key, value)
      return if spans.empty?

      spans.last.trace.add_field("app.#{key}", value)
    end

    private

    attr_reader :client, :context

    def host_name
      # Send the heroku dyno name instead of hostname if available
      ENV["DYNO"] || Socket.gethostname
    end
  end
end
