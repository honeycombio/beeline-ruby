# frozen_string_literal: true

module Honeycomb
  # Used to configure the Honeycomb client
  class Configuration
    attr_accessor :write_key,
                  :dataset,
                  :api_host

    attr_writer :service_name, :client, :host_name

    def initialize
      @write_key = ENV["HONEYCOMB_WRITEKEY"]
      @dataset = ENV["HONEYCOMB_DATASET"]
      @service_name = ENV["HONEYCOMB_SERVICE"]
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

      @client || Libhoney::Client.new(options)
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
  end
end
