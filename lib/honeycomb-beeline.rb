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

      libhoney = Libhoney::Client.new(writekey: configuration.write_key,
                                      dataset: configuration.dataset)
      @client = Honeycomb::Client.new(client: libhoney,
                                      service_name: configuration.service_name)
    end

    def start_span(name:)
      client.start_span(name: name)
    end

    def load_integrations
      require "honeycomb/integrations/railtie" if defined?(Rails::Railtie)
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
                  :dataset,
                  :service_name

    def initialize
      @write_key = ENV["HONEYCOMB_WRITEKEY"]
      @dataset = ENV["HONEYCOMB_DATASET"]
      @service_name = ENV["HONEYCOMB_SERVICE"] || dataset
    end
  end
end

Honeycomb.load_integrations unless ENV["HONEYCOMB_DISABLE_AUTOCONFIGURE"]
