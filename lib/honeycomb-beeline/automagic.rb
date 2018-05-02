# Alternative entrypoint for the 'honeycomb-beeline' gem that detects libraries
# we can instrument and automagically instrument them.

require 'libhoney'

require 'honeycomb/client'
require 'honeycomb/span'

module Honeycomb
end

require 'activerecord-honeycomb/automagic'
require 'faraday-honeycomb/automagic'
require 'rack-honeycomb/automagic'

require 'honeycomb/env_config'
if Honeycomb::ENV_CONFIG
  Honeycomb.init(**Honeycomb::ENV_CONFIG)
end
