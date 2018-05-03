# Alternative entrypoint for the 'honeycomb-beeline' gem that detects libraries
# we can instrument and automagically instrument them.

require 'libhoney'

require 'honeycomb/client'
require 'honeycomb/span'

require 'activerecord-honeycomb/auto_install'
require 'faraday-honeycomb/auto_install'
require 'rack-honeycomb/auto_install'
require 'sequel-honeycomb/auto_install'

require 'honeycomb/env_config'

module Honeycomb
  module Beeline
    LOGGER = if Honeycomb::DEBUG
      require 'logger'
      Logger.new($stderr).tap do |l|
        l.level = Logger::Severity.const_get(Honeycomb::DEBUG)
      end
    end

    INSTRUMENTATIONS = [
      ActiveRecord::Honeycomb,
      Faraday::Honeycomb,
      Rack::Honeycomb,
      Sequel::Honeycomb,
    ].freeze

    INSTRUMENTATIONS.each do |instrumentation|
      auto = instrumentation::AutoInstall
      if auto.available?(logger: LOGGER)
        hook_label = instrumentation.name.sub(/::Honeycomb$/, '').downcase.to_sym
        Honeycomb.after_init(hook_label) do |client|
          auto.auto_install!(honeycomb_client: client, logger: LOGGER)
        end
      else
        LOGGER.debug "Not autoinitialising #{instrumentation.name}" if LOGGER
      end
    end
  end
end

if Honeycomb::ENV_CONFIG
  Honeycomb.init(logger: Honeycomb::Beeline::LOGGER, **Honeycomb::ENV_CONFIG)
end
