# frozen_string_literal: true

require "libhoney"

require "honeycomb/beeline/version"
require "honeycomb/client"
require "honeycomb/trace"

# main module
module Honeycomb
  INTEGRATIONS = %i[
    active_support
    faraday
    rack
    rails
    sequel
    sinatra
  ].freeze

  class << self
    attr_reader :client

    def configure
      Configuration.new.tap do |config|
        yield config
        @client = Honeycomb::Client.new(configuration: config)
      end

      @client
    end

    def start_span(name:, &block)
      client.start_span(name: name, &block)
    end

    def load_integrations
      INTEGRATIONS.each do |integration|
        begin
          require "honeycomb/integrations/#{integration}"
        rescue LoadError
        end
      end
    end
  end
end

Honeycomb.load_integrations unless ENV["HONEYCOMB_DISABLE_AUTOCONFIGURE"]
