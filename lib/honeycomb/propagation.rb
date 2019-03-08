# frozen_string_literal: true

require "base64"
require "json"

module Honeycomb
  # Parse trace headers
  module PropagationParser
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
        case key
        when "dataset"
          dataset = value
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
  module PropagationSerializer
    def to_trace_header
      context = Base64.urlsafe_encode64(JSON.generate(trace.fields)).strip
      "1;trace_id=#{trace.id},parent_id=#{id},context=#{context}"
    end
  end
end
