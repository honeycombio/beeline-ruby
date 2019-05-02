# frozen_string_literal: true

require "libhoney"

require "honeycomb/beeline/version"
require "honeycomb/client"
require "honeycomb/trace"

# main module
module Honeycomb
  class << self
    attr_reader :client

    def configure
      Configuration.new.tap do |config|
        yield config
        @client = Honeycomb::Client.new(client: config.client,
                                        service_name: config.service_name)
      end

      @client
    end

    def start_span(name:, &block)
      client.start_span(name: name, &block)
    end

    def load_integrations
      %i[faraday rack sinatra rails sequel active_support].each do |integration|
        begin
          require "honeycomb/integrations/#{integration}"
        rescue LoadError
        end
      end
    end
  end

  # Used to configure the Honeycomb client
  class Configuration
    attr_accessor :write_key,
                  :dataset,
                  :api_host

    attr_writer :service_name, :client

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
  end
end

Honeycomb.load_integrations unless ENV["HONEYCOMB_DISABLE_AUTOCONFIGURE"]
