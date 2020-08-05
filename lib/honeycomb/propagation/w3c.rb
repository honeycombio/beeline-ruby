# frozen_string_literal: true

module Honeycomb
  # Parsing and propagation for W3C trace headers
  module W3CPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        unless serialized_trace.nil?
          version, payload = serialized_trace.split("-", 2)
          if version == "00"
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
        invalid_trace_id = "00000000000000000000000000000000"
        invalid_span_id = "0000000000000000"

        trace_id, parent_span_id, trace_flags = payload.split("-", 3)

        if trace_flags.nil?
          # if trace_flags is nil, it means a field is missing
          return [nil, nil]
        end

        if trace_id == invalid_trace_id || parent_span_id == invalid_span_id
          return [nil, nil]
        end

        [trace_id, parent_span_id]
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header
        "00-#{trace.id}-#{id}-01" unless trace.id.nil?
      end
    end
  end
end
