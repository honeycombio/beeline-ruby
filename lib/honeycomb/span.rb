# frozen_string_literal: true

require "forwardable"

module Honeycomb
  # Represents a Honeycomb span, which wraps a Honeycomb event and adds specific
  # tracing functionality
  class Span
    extend Forwardable

    def_delegators :@event, :add_field, :add

    def initialize(trace:, event:)
      @event = event
      @trace = trace
      @rollup_fields = Hash.new(0)
    end

    def add_rollup_field(key, value)
      trace.add_rollup_field(key, value)
      rollup_fields[key] += value
    end

    def add_trace_field(key, value)
      trace.add_field(key, value)
    end

    def send; end

    private

    attr_reader :trace, :rollup_fields
  end
end
