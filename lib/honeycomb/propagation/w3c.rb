# frozen_string_literal: true

module Honeycomb
  # Parsing and propagation for W3C trace headers
  module W3CPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      INVALID_TRACE_ID = "00000000000000000000000000000000".freeze
      INVALID_SPAN_ID = "0000000000000000".freeze

      def parse(serialized_trace)
        unless serialized_trace.nil?
          version, payload = serialized_trace.split("-", 2)
          # version should be 2 hex characters
          if version =~ /^[A-Fa-f0-9]{2}$/
            trace_id, parent_span_id = parse_v1(payload)

            if !trace_id.nil? && !parent_span_id.nil?
              # return nil for dataset
              return [trace_id, parent_span_id, nil, nil]
            end
          end
        end
        [nil, nil, nil, nil]
      end

      def parse_v1(payload)
        trace_id, parent_span_id, trace_flags = payload.split("-", 3)

        if trace_flags.nil?
          # if trace_flags is nil, it means a field is missing
          return [nil, nil]
        end

        if trace_id == INVALID_TRACE_ID || parent_span_id == INVALID_SPAN_ID
          return [nil, nil]
        end

        [trace_id, parent_span_id]
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      TRACE_ID_REGEX = /^[A-Fa-f0-9]{32}$/.freeze
      SPAN_ID_REGEX = /^[A-Fa-f0-9]{16}$/.freeze

      def to_trace_header(propagation_context: nil)
        if propagation_context.nil?
          trace_id = trace.id
          span_id = id
        else
          trace_id, span_id = propagation_context
        end
        # do not propagate malformed ids
        if trace_id =~ TRACE_ID_REGEX && span_id =~ SPAN_ID_REGEX
          return "00-#{trace_id}-#{span_id}-01"
        end

        nil
      end
    end

    # Class for easy importing
    class Parser
      include Honeycomb::W3CPropagation::UnmarshalTraceContext
      def http_trace_parser_hook(env)
        trace_header = env["HTTP_TRACEPARENT"]
        parse(trace_header)
      end
    end

    # class for easy importing and custom usage
    class Propagator
      include Honeycomb::W3CPropagation::MarshalTraceContext
      def http_trace_propagation_hook(propagation_context)
        serialized = to_trace_header(propagation_context: propagation_context)
        { "traceparent" => serialized }
      end
    end
  end
end
