require 'honeycomb/client'

require 'activerecord-honeycomb/auto_install'
require 'faraday-honeycomb/auto_install'
require 'rack-honeycomb/auto_install'
require 'sequel-honeycomb/auto_install'

module Honeycomb
  INSTRUMENTATIONS = [
    ActiveRecord::Honeycomb,
    Faraday::Honeycomb,
    Rack::Honeycomb,
    Sequel::Honeycomb,
  ].freeze

  INSTRUMENTATIONS.each do |instrumentation|
    auto = instrumentation::AutoInstall
    if auto.available?
      hook_label = instrumentation.name.sub(/::Honeycomb$/, '').downcase.to_sym
      after_init(hook_label) do |client|
        auto.auto_install!(honeycomb_client: client, logger: @logger)
      end
    end
  end
end
