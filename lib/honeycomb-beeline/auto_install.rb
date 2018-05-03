# Alternative entrypoint for the 'honeycomb-beeline' gem that detects libraries
# we can instrument and automagically instrument them.

require 'libhoney'

require 'honeycomb/client'
require 'honeycomb/span'

require 'activerecord-honeycomb/auto_install'
require 'faraday-honeycomb/auto_install'
require 'rack-honeycomb/auto_install'
require 'sequel-honeycomb/auto_install'

module Honeycomb
  module Beeline
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
        Honeycomb.after_init(hook_label) do |client|
          auto.auto_install!(client)
        end
      else
        puts "Not autoinitialising #{instrumentation.name}" # TODO
      end
    end
  end
end

require 'honeycomb/env_config'
if Honeycomb::ENV_CONFIG
  Honeycomb.init(**Honeycomb::ENV_CONFIG)
end
