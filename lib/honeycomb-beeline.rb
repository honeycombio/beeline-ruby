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
      # only allow configuration once
      return if defined?(@client)

      configuration = Configuration.new

      yield configuration

      @client = Honeycomb::Client.new(client: configuration.client,
                                      service_name: configuration.service_name)
    end

    def start_span(name:)
      client.start_span(name: name)
    end

    def load_integrations
      %i[faraday rack rails sequel].each do |integration|
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
                  :dataset

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
      @client || Libhoney::Client.new(writekey: write_key,
                                      dataset: dataset)
    end
  end
end

Honeycomb.load_integrations unless ENV["HONEYCOMB_DISABLE_AUTOCONFIGURE"]
