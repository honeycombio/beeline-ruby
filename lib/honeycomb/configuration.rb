# frozen_string_literal: true

require "socket"
require "honeycomb/propagation/default"

module Honeycomb
  # Used to configure the Honeycomb client
  class Configuration
    attr_accessor :write_key,
                  :api_host,
                  :debug

    attr_writer :service_name, :client, :host_name, :dataset
    attr_reader :error_backtrace_limit

    def initialize
      @write_key = ENV["HONEYCOMB_WRITEKEY"]
      @dataset = ENV["HONEYCOMB_DATASET"]
      @service_name = ENV["HONEYCOMB_SERVICE"]
      @debug = ENV.key?("HONEYCOMB_DEBUG")
      @error_backtrace_limit = 0
      @client = nil
    end

    def is_classic
      @write_key.length == 32
    end

    def service_name
      @service_name || dataset
    end

    def dataset
      @dataset
    end

    def error_backtrace_limit=(val)
      @error_backtrace_limit = Integer(val)
    end

    def client
      # memoized:
      # either the user has supplied a pre-configured Libhoney client
      @client ||=
        # or we'll create one and return it from here on
        if debug
          Libhoney::LogClient.new
        else
          Libhoney::Client.new(**libhoney_client_options)
        end
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
        DefaultPropagation::UnmarshalTraceContext.method(:parse_rack_env)
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

    private

    def libhoney_client_options
      {
        writekey: write_key,
        dataset: dataset,
        user_agent_addition: Honeycomb::Beeline::USER_AGENT_SUFFIX,
      }.tap do |options|
        # only set the API host for the client if one has been given
        options[:api_host] = api_host if api_host
      end
    end
  end
end
