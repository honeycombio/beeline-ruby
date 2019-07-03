require 'honeycomb/client'

require 'faraday-honeycomb/auto_install'
require 'rack-honeycomb/auto_install'

module Honeycomb
  INSTRUMENTATIONS = [
    Faraday::Honeycomb,
    Rack::Honeycomb,
  ].freeze

  INSTRUMENTATIONS.each do |instrumentation|
    auto = instrumentation::AutoInstall
    hook_label = instrumentation.name.sub(/::Honeycomb$/, '').downcase.to_sym
    after_init(hook_label) do |client, logger|
      if auto.available?(logger: logger)
        auto.auto_install!(honeycomb_client: client, logger: logger)
      else
        logger.debug "Not autoinitialising #{instrumentation.name}" if logger
      end
    end
  end
end
