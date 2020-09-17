# frozen_string_literal: true

module Honeycomb
  # Parsing and propagation for W3C trace headers
  module W3CPropagation
    # Class for easy importing
    class Parser
      INVALID_TRACE_ID = "00000000000000000000000000000000".freeze
      INVALID_SPAN_ID = "0000000000000000".freeze

      def http_trace_parser_hook(env)
        trace_header = env["HTTP_TRACEPARENT"]
        unmarshal_trace_context(trace_header)
      end

      def unmarshal_trace_context(serialized_trace)
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

    # Class for easy importing and custom usage
    class Propagator
      TRACE_ID_REGEX = /^[A-Fa-f0-9]{32}$/.freeze
      SPAN_ID_REGEX = /^[A-Fa-f0-9]{16}$/.freeze

      def http_trace_propagation_hook(propagation_context)
        serialized = marshal_trace_context(propagation_context)
        { "traceparent" => serialized }
      end

      def marshal_trace_context(propagation_context)
        trace_id, span_id = propagation_context
        # do not propagate malformed ids
        if trace_id =~ TRACE_ID_REGEX && span_id =~ SPAN_ID_REGEX
          return "00-#{trace_id}-#{span_id}-01"
        end

        nil
      end
    end

    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        parser = Parser.new
        parser.unmarshal_trace_context(serialized_trace)
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header
        propagator = Propagator.new

        trace_id = trace.id
        span_id = id
        trace_fields = trace.fields
        dataset = builder.dataset

        propagation_context = [trace_id, span_id, trace_fields, dataset]
        propagator.marshal_trace_context(propagation_context)
      end
    end
  end
end
