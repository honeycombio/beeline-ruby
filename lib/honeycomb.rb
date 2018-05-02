# Main entrypoint for the 'honeycomb' gem (see also lib/honeycomb/automagic.rb
# for an alternative entrypoint).

require 'libhoney'

require 'honeycomb/client'
require 'honeycomb/span'

require 'activerecord-honeycomb'
require 'faraday-honeycomb'

module Honeycomb
end
