# frozen_string_literal: true

require "socket"
require "forwardable"
require "honeycomb/beeline/version"

module Honeycomb
  # The Honeycomb Beeline client
  class Client
    extend Forwardable

    def initialize(client:)
      client.add_field "meta.beeline_version", Honeycomb::Beeline::VERSION
      client.add_field "meta.local_hostname", host_name
      @client = client
      @spans = []
      @trace = nil

      at_exit do
        client.close
      end
    end

    def start_span(name:)
      new_span
      spans.last.tap do |current_span|
        current_span.add_field("name", name)

        if block_given?
          begin
            yield current_span
          rescue StandardError => e
            span.add_field("request.error", e.class.name)
            span.add_field("request.error_detail", e.message)
            raise e
          ensure
            current_span.send
            spans.pop
            spans.empty? && self.trace = nil
          end
        end
      end
    end

    def add_field(key, value)
      return if spans.empty?

      spans.last.add_field("app.#{key}", value)
    end

    def add_field_to_trace(key, value)
      return if spans.empty?

      spans.last.trace.add_field("app.#{key}", value)
    end

    private

    attr_accessor :trace
    attr_reader :client, :spans

    def new_span
      if trace.nil?
        self.trace = Trace.new(builder: client.builder)
        spans << trace.root_span
      else
        spans << spans.last.create_child
      end
    end

    def host_name
      # Send the heroku dyno name instead of hostname if available
      ENV["DYNO"] || Socket.gethostname
    end
  end
end
