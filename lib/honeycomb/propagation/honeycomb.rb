# frozen_string_literal: true

require "base64"
require "json"
require "uri"

module Honeycomb
  # Parsing and propagation for honeycomb trace headers
  module HoneycombPropagation
    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        unless serialized_trace.nil?
          version, payload = serialized_trace.split(";", 2)

          if version == "1"
            trace_id, parent_span_id, trace_fields, dataset = parse_v1(payload)

            if !trace_id.nil? && !parent_span_id.nil?
              return [trace_id, parent_span_id, trace_fields, dataset]
            end
          end
        end

        [nil, nil, nil, nil]
      end

      def parse_v1(payload)
        trace_id, parent_span_id, trace_fields, dataset = nil
        payload.split(",").each do |entry|
          key, value = entry.split("=", 2)
          case key.downcase
          when "dataset"
            dataset = URI.decode_www_form_component(value)
          when "trace_id"
            trace_id = value
          when "parent_id"
            parent_span_id = value
          when "context"
            Base64.decode64(value).tap do |json|
              begin
                trace_fields = JSON.parse json
              rescue JSON::ParserError
                trace_fields = {}
              end
            end
          end
        end

        [trace_id, parent_span_id, trace_fields, dataset]
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header(propagation_context: nil)
        if propagation_context.nil?
          trace_id = trace.id
          span_id = id
          trace_fields = trace.fields
          dataset = builder.dataset
        else
          trace_id, span_id, trace_fields, dataset = propagation_context
        end

        encoded_trace_fields = Base64.urlsafe_encode64(
          JSON.generate(trace_fields),
        ).strip

        encoded_dataset = URI.encode_www_form_component(dataset)

        data_to_propagate = [
          "trace_id=#{trace_id}",
          "parent_id=#{span_id}",
          "context=#{encoded_trace_fields}",
          "dataset=#{encoded_dataset}",
        ]
        "1;#{data_to_propagate.join(',')}"
      end
    end

    # Class for easy importing
    class Parser
      include Honeycomb::HoneycombPropagation::UnmarshalTraceContext
      def unmarshal_trace_context(env)
        trace_header = env["HTTP_X_HONEYCOMB_TRACE"]
        parse(trace_header)
      end
    end

    # blah blah propagator
    class Propagator
      include Honeycomb::HoneycombPropagation::MarshalTraceContext
      def marshal_trace_context(propagation_context)
        serialized = to_trace_header(propagation_context: propagation_context)
        { "X-Honeycomb-Trace" => serialized }
      end
    end
  end
end
