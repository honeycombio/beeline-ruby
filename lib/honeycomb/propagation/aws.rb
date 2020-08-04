# frozen_string_literal: true

require "base64"
require "json"
require "uri"

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

          trace_fields = {} if trace_fields.nil?

          if !trace_id.nil? && !parent_span_id.nil?
            return [trace_id, parent_span_id, trace_fields]
          end
        end

        [nil, nil, nil, nil]
      end

      def get_fields(fields)
        trace_fields = {}
        fields.each do |entry|
          key, value = entry.split("=", 2)
          case key.downcase
          when "root"
            trace_id = value
          when "parent"
            parent_span_id = value
          when "self"
            parent_span_id = value
          else
            trace_fields[key] = value
          end
          return [trace_id, parent_span_id, trace_fields]
        end
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header
        context = ""
        unless trace.fields.keys.nil?
          trace.fields.keys.each do |key|
            context.concat(";#{[key]}=#{trace.fields[key]}")
          end
        end

        data_to_propogate = [
          "Root=#{trace.id}",
          "Parent=#{id}",
        ]
        "#{data_to_propogate.join(';')}#{context}"
      end
    end
  end
end
