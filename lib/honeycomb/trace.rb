# frozen_string_literal: true

require "forwardable"
require "securerandom"
require "honeycomb/span"
require "honeycomb/propagation"

module Honeycomb
  # Represents a Honeycomb trace, which groups spans together
  class Trace
    include PropagationParser
    extend Forwardable

    def_delegators :@root_span, :send

    attr_reader :id, :fields, :root_span, :rollup_fields

    def initialize(builder:, context:, serialized_trace: nil)
      trace_id, parent_span_id, trace_fields, dataset =
        parse serialized_trace
      dataset && builder.dataset = dataset
      @id = trace_id || SecureRandom.uuid
      @rollup_fields = Hash.new(0)
      @fields = trace_fields || {}
      @root_span = Span.new(trace: self,
                            parent_id: parent_span_id,
                            is_root: true,
                            builder: builder,
                            context: context)
    end

    def add_field(key, value)
      @fields[key] = value
    end

    def add_rollup_field(key, value)
      @rollup_fields[key] += value
    end
  end
end
