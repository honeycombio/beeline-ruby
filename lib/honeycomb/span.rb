require 'securerandom'

module Honeycomb
  module Span
  end

  class << self
    def with_trace_id(trace_id = SecureRandom.uuid)
      Thread.current[:honeycomb_trace_id] = trace_id
      yield trace_id
    ensure
      Thread.current[:honeycomb_trace_id] = nil
    end

    def trace_id
      Thread.current[:honeycomb_trace_id]
    end

    def with_span_id(span_id)
      parent_span_id = Thread.current[:honeycomb_span_id]
      Thread.current[:honeycomb_span_id] = span_id
      yield parent_span_id
    ensure
      Thread.current[:honeycomb_span_id] = parent_span_id
    end

    # TODO rethink this API
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
  end
end
