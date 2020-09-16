# frozen_string_literal: true

module Honeycomb
  # Parsing and propagation for W3C trace headers
  module W3CPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      INVALID_TRACE_ID = "00000000000000000000000000000000".freeze
      INVALID_SPAN_ID = "0000000000000000".freeze

      def http_trace_parser_hook(env)
        header = env["HTTP_TRACEPARENT"]
        parse(header)
      end

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

      def to_trace_header(context: nil)
        trace_id, span_id = context
        unless trace_id.nil? || span_id.nil?
          return "00-#{trace_id}-#{span_id}-01"
        end

        nil
      end

      def create_hash(context: nil)
        { "traceparent" => to_trace_header(context: context) }
      end
    end
  end
end
