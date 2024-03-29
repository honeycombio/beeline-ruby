# frozen_string_literal: true

require "base64"
require "json"
require "uri"
require "libhoney/cleaner"

module Honeycomb
  # Parsing and propagation for honeycomb trace headers
  module HoneycombModernPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      def parse_rack_env(env)
        parse env["HTTP_X_HONEYCOMB_TRACE"]
      end

      def parse(serialized_trace)
        unless serialized_trace.nil?
          version, payload = serialized_trace.split(";", 2)

          if version == "1"
            trace_id, parent_span_id, trace_fields = parse_v1(payload)

            if !trace_id.nil? && !parent_span_id.nil?
              return [trace_id, parent_span_id, trace_fields, nil]
            end
          end
        end

        [nil, nil, nil, nil]
      end

      def parse_v1(payload)
        trace_id, parent_span_id, trace_fields = nil
        payload.split(",").each do |entry|
          key, value = entry.split("=", 2)
          case key.downcase
          when "trace_id"
            trace_id = value
          when "parent_id"
            parent_span_id = value
          when "context"
            Base64.urlsafe_decode64(value).tap do |json|
              trace_fields = JSON.parse json
            rescue JSON::ParserError
              trace_fields = {}
            end
          end
        end

        [trace_id, parent_span_id, trace_fields, nil]
      end

      module_function :parse_rack_env, :parse, :parse_v1
      public :parse_rack_env, :parse
    end

    # Serialize trace headers
    module MarshalTraceContext
      # for cleaning data in trace fields before serializing to prop header value
      include Libhoney::Cleaner
      # promote cleaner instance methods to module methods so that self.to_trace_header can use them
      module_function :clean_data, :clean_string

      def to_trace_header
        data_to_propogate = [
          "trace_id=#{trace.id}",
          "parent_id=#{id}",
          "context=#{encode_trace_fields(trace.fields)}",
        ]
        "1;#{data_to_propogate.join(',')}"
      end

      def self.parse_faraday_env(_env, propagation_context)
        {
          "X-Honeycomb-Trace" => to_trace_header(propagation_context),
        }
      end

      def self.to_trace_header(propagation_context)
        data_to_propogate = [
          "trace_id=#{propagation_context.trace_id}",
          "parent_id=#{propagation_context.parent_id}",
          "context=#{encode_trace_fields(propagation_context.trace_fields)}",
        ]
        "1;#{data_to_propogate.join(',')}"
      end

      def encode_trace_fields(fields)
        Base64.urlsafe_encode64(
          JSON.generate(
            clean_data(fields),
          ),
        ).strip
      end
      module_function :encode_trace_fields
    end
  end
end
