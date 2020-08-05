# frozen_string_literal: true

require "base64"
require "json"
require "uri"

module Honeycomb
  # Parsing and propagation for W3C trace headers
  module W3CPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        unless serialized_trace.nil?
          version, payload = serialized_trace.split("-", 1)

          if version == "00"
            trace_id, parent_span_id, trace_fields = parse_v1(payload)

            if !trace_id.nil? && !parent_span_id.nil?
              # return nil for dataset
              return [trace_id, parent_span_id, trace_fields, nil]
            end
          end
        end

        [nil, nil, nil]
      end

      def parse_v1(payload)
        @invalid_trace_id = "00000000000000000000000000000000"
        @invalid_span_id = "0000000000000000"

        trace_id, parent_span_id = payload.split("-", 2)

        if trace_id == @invalid_trace_id || parent_span_id == @invalid_span_id
          return [nil, nil]
        end

        [trace_id, parent_span_id]
      end
    end
  end
end
