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

    # parse_request both pulls the trace headers out
    # and parses them, returning a propagation context
    def parse_request(env, parser_hook: nil)
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
    def create_headers
      if propagation_hook.nil?
        create_hash
      else
        propagation_hook.call(propagation_context_from_span)
      end
    rescue StandardError => e
      raise e
    end
  end
end
