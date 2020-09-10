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

    def parse(env, parser_hook: nil)
      if parser_hook.nil?
        http_trace_parser_hook(env)
      else
        parser_hook.call(env)
      end
    end
  end

  # Serialize trace headers
  module PropagationSerializer
    include HoneycombPropagation::MarshalTraceContext
  end
end
