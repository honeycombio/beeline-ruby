# frozen_string_literal: true

require "base64"
require "json"
require "uri"

module Honeycomb
  # Parsing and propagation for honeycomb trace headers
  module HoneycombPropagation
    # class for easy importing and custom usage
    class Propagator
      def http_trace_propagation_hook(propagation_context)
        serialized = marshal_trace_context(propagation_context)
        { "X-Honeycomb-Trace" => serialized }
      end

      def marshal_trace_context(propagation_context)
        trace_id, span_id, trace_fields, dataset = propagation_context

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
      def http_trace_parser_hook(env)
        trace_header = env["HTTP_X_HONEYCOMB_TRACE"]
        unmarshal_trace_context(trace_header)
      end

      def unmarshal_trace_context(serialized_trace)
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

    # Parse trace headers
    module UnmarshalTraceContext
      def parse(serialized_trace)
        parser = HoneycombPropagation::Parser.new
        parser.unmarshal_trace_context(serialized_trace)
      end
    end

    # Serialize trace headers
    module MarshalTraceContext
      def to_trace_header
        propagator = HoneycombPropagation::Propagator.new

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
