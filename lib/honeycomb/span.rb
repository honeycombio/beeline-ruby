require 'base64'
require 'json'
require 'securerandom'

module Honeycomb
  class << self
    # @api private
    def with_trace_context(encoded_context = nil)
      trace_context = decode_trace_context(encoded_context) || {}
      trace_id = trace_context.fetch(:trace_id, SecureRandom.uuid)
      parent_span_id = trace_context[:parent_span_id]
      context = trace_context.fetch(:context, {})

      Thread.current[:honeycomb_trace_id] = trace_id
      yield trace_id, parent_span_id, context
    ensure
      Thread.current[:honeycomb_trace_id] = nil
    end

    # @api private
    def trace_id
      Thread.current[:honeycomb_trace_id]
    end

    # @api private
    def with_span_id(span_id)
      parent_span_id = Thread.current[:honeycomb_span_id]
      Thread.current[:honeycomb_span_id] = span_id
      yield parent_span_id
    ensure
      Thread.current[:honeycomb_span_id] = parent_span_id
    end

    # @api private
    def span(service_name:, name:, span_id: SecureRandom.uuid)
      event = client.event

      event.add_field 'trace.trace_id', trace_id if trace_id
      event.add_field 'service_name', service_name
      event.add_field 'name', name
      event.add_field 'trace.span_id', span_id

      start = Time.now
      with_span_id(span_id) do |parent_span_id|
        event.add_field 'trace.parent_id', parent_span_id if parent_span_id
        yield
      end
    rescue Exception => e
      if event
        # TODO what should the prefix be?
        event.add_field 'app.error', e.class.name
        event.add_field 'app.error_detail', e.message
      end
      raise
    ensure
      if start && event
        finish = Time.now
        duration = finish - start
        event.add_field 'duration_ms', duration * 1000
        event.send
      end
    end

    def decode_trace_context(encoded_context)
      return nil unless encoded_context
      version, payload = encoded_context.split(';', 2)
      case version
      when '1'
        decode_payload_v1(payload)
      else
        nil
      end
    end

    def encode_trace_context_v1(trace_id, parent_span_id, context)
      version = 1

      encoded_payload = encode_payload_v1(
        trace_id: trace_id,
        parent_id: parent_span_id,
        context: context,
      )

      "#{version};#{encoded_payload}"
    end
    alias encode_trace_context encode_trace_context_v1

    private
    def decode_payload_v1(encoded_payload)
      trace_id, parent_span_id, context = nil

      encoded_payload.split(',').each do |entry|
        k, v = entry.split('=', 2)
        case k
        when 'trace_id'
          trace_id = v
        when 'parent_id'
          parent_span_id = v
        when 'context'
          context = decode_payload_context_v1(v)
        else
        end
      end

      if trace_id.nil?
        return nil
      elsif parent_span_id.nil?
        return nil
      end

      payload = {
        trace_id: trace_id,
        parent_span_id: parent_span_id,
      }
      payload[:context] = context if context
      payload
    rescue StandardError => e
      nil
    end

    def decode_payload_context_v1(encoded_payload_context)
      return {} if encoded_payload_context.empty?
      json = Base64.decode64(encoded_payload_context)
      JSON.parse(json)
    end

    def encode_payload_v1(payload_parts)
      payload_parts.map do |k, v|
        encoded_part = encode_payload_part_v1(k, v)
        encoded_part ? "#{k}=#{encoded_part}" : nil
      end
        .compact # strip out parts that failed to encode
        .join(',')
    end

    def encode_payload_part_v1(param, value)
      case param
      when :trace_id, :parent_id
        encode_payload_id_v1(value)
      when :context
        encode_payload_context_v1(value)
      end
    end

    def encode_payload_id_v1(id)
      case id
      when nil
        nil
      when String, Symbol
        id = id.to_s
        if id.include? ','
          raise ArgumentError, "can't include ','"
        end
        id
      when Numeric
        id.to_s
      else
        raise ArgumentError, "invalid type #{id.class}"
      end
    end

    def encode_payload_context_v1(context)
      case context
      when nil
        nil
      when Hash
        Base64.urlsafe_encode64(JSON.generate(context)).strip
      else
        raise ArgumentError, "invalid type #{context.class}"
      end
    end
  end
end
