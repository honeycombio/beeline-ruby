# frozen_string_literal: true

module Honeycomb
  # Parsing and propagation for AWS trace headers
  module AWSPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        unless serialized_trace.nil?
          split = serialized_trace.split(";")

          trace_id, parent_span_id, trace_fields = get_fields(split)

          parent_span_id = trace_id if parent_span_id.nil?

          trace_fields = nil if trace_fields.empty?

          if !trace_id.nil? && !parent_span_id.nil?
            # return nil for dataset
            return [trace_id, parent_span_id, trace_fields, nil]
          end
        end

        [nil, nil, nil, nil]
      end

      def get_fields(fields)
        trace_id, parent_span_id = nil
        trace_fields = {}
        fields.each do |entry|
          key, value = entry.split("=", 2)
          case key.downcase
          when "root"
            trace_id = value
          when "self"
            parent_span_id = value
          when "parent"
            parent_span_id = value if parent_span_id.nil?
          else
            trace_fields[key] = value unless key.empty?
          end
        end

        [trace_id, parent_span_id, trace_fields]
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header(propagation_context: nil)
        if propagation_context.nil?
          trace_id = trace.id
          span_id = id
          trace_fields = trace.fields
        else
          trace_id, span_id, trace_fields = propagation_context
        end

        context = [""]
        unless trace_fields.keys.nil?
          trace_fields.keys.each do |key|
            context.push("#{key}=#{trace_fields[key]}")
          end
        end

        data_to_propagate = [
          "Root=#{trace_id}",
          "Parent=#{span_id}",
        ]
        "#{data_to_propagate.join(';')}#{context.join(';')}"
      end
    end

    # Class for easy importing
    class Parser
      include Honeycomb::AWSPropagation::UnmarshalTraceContext
      def http_trace_parser_hook(env)
        trace_header = env["HTTP_X_AMZN_TRACE_ID"]
        parse(trace_header)
      end
    end

    # class for easy importing and custom usage
    class Propagator
      include Honeycomb::AWSPropagation::MarshalTraceContext
      def http_trace_propagation_hook(propagation_context)
        serialized = to_trace_header(propagation_context: propagation_context)
        { "X-Amzn-Trace-Id" => serialized }
      end
    end
  end
end
