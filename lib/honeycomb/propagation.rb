# frozen_string_literal: true

require "base64"
require "json"
require "uri"

require "honeycomb/propagation/honeycomb"
require "honeycomb/propagation/w3c"
require "honeycomb/propagation/aws"

module Honeycomb
  # Parse trace headers
  module PropagationParser
    include HoneycombPropagation::UnmarshalTraceContext
  end

  # Serialize trace headers
  module PropagationSerializer
    include HoneycombPropagation::MarshalTraceContext
  end
end
