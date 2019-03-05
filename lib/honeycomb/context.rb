# frozen_string_literal: true

module Honeycomb
  # Stores the current span and trace context
  class Context
    def current_trace
      return if current_span.nil?

      current_span.trace
    end

    def current_span
      spans.last
    end

    def current_span=(span)
      spans << span
    end

    def span_sent(span)
      spans.last != span && raise(ArgumentError, "Incorrect span sent")

      spans.pop
    end

    private

    def spans
      storage["spans"] ||= []
    end

    def storage
      Thread.current[thread_key] ||= {}
    end

    def thread_key
      @thread_key ||= ["honeycomb", self.class.name, object_id].join("-")
    end
  end
end
