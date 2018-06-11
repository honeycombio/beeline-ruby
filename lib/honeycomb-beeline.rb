# Main entrypoint for the 'honeycomb-beeline' gem.

require 'libhoney'

# Namespace for the Honeycomb Beeline.
#
# Call {.init} to initialize the Honeycomb Beeline at app startup.
module Honeycomb
end

require 'honeycomb/client'
require 'honeycomb/instrumentations'
require 'honeycomb/span'
