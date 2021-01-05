# frozen_string_literal: true

require "socket"
require "honeycomb/propagation/honeycomb"

module Honeycomb
  # Used to configure the Honeycomb client
  class Configuration
    attr_accessor :write_key,
                  :dataset,
                  :api_host,
                  :debug

    attr_writer :service_name, :client, :host_name

    def initialize
      @write_key = ENV["HONEYCOMB_WRITEKEY"]
      @dataset = ENV["HONEYCOMB_DATASET"]
      @service_name = ENV["HONEYCOMB_SERVICE"]
      @debug = ENV.key?("HONEYCOMB_DEBUG")
      @client = nil
    end

    def service_name
      @service_name || dataset
    end

    def client
      options = {}.tap do |o|
        o[:writekey] = write_key
        o[:dataset] = dataset
        api_host && o[:api_host] = api_host
      end

      @client ||
        (debug && Libhoney::LogClient.new) ||
        Libhoney::Client.new(**options)
    end

    def after_initialize(client)
      super(client) if defined?(super)
    end

    def host_name
      # Send the heroku dyno name instead of hostname if available
      @host_name || ENV["DYNO"] || Socket.gethostname
    end

    def presend_hook(&hook)
      if block_given?
        @presend_hook = hook
      else
        @presend_hook
      end
    end

    def sample_hook(&hook)
      if block_given?
        @sample_hook = hook
      else
        @sample_hook
      end
    end

    def http_trace_parser_hook(&hook)
      if block_given?
        @http_trace_parser_hook = hook
      elsif @http_trace_parser_hook
        @http_trace_parser_hook
      else
        # by default we try to parse incoming honeycomb traces
        HoneycombPropagation::UnmarshalTraceContext.method(:parse_rack_env)
      end
    end

    def http_trace_propagation_hook(&hook)
      if block_given?
        @http_trace_propagation_hook = hook
      elsif @http_trace_propagation_hook
        @http_trace_propagation_hook
      else
        # by default we send outgoing honeycomb trace headers
        HoneycombPropagation::MarshalTraceContext.method(:parse_faraday_env)
      end
    end
  end
end
