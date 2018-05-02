# Main entrypoint for the 'honeycomb-beeline' gem (see also
# lib/honeycomb-beeline/automagic.rb for an alternative entrypoint).

require 'libhoney'

require 'honeycomb/client'
require 'honeycomb/span'

require 'activerecord-honeycomb'
require 'faraday-honeycomb'

module Honeycomb
end
