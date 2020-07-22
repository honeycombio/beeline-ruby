# frozen_string_literal: true

require "forwardable"
require "honeycomb/span"
require "honeycomb/propagation"
require "honeycomb/rollup_fields"

module Honeycomb
  # Represents a Honeycomb trace, which groups spans together
  class Trace
    include PropagationParser
    include RollupFields
    extend Forwardable

    INVALID_TRACE_ID = ("\0" * 16).b

    def_delegators :@root_span, :send

    attr_reader :id, :fields, :root_span

    INVALID_TRACE_ID = ("\0" * 16).b

    def generate_trace_id()
      loop do
        id = Random::DEFAULT.bytes(16)
        return id unless id == INVALID_TRACE_ID
      end
    end

    def initialize(builder:, context:, serialized_trace: nil, **options)
      trace_id, parent_span_id, trace_fields, dataset =
        parse serialized_trace
      dataset && builder.dataset = dataset
      @id = trace_id || generate_trace_id()
      @fields = trace_fields || {}
      @root_span = Span.new(trace: self,
                            parent_id: parent_span_id,
                            is_root: true,
                            builder: builder,
                            context: context,
                            **options)
    end

    def add_field(key, value)
      @fields[key] = value
    end
  end
end
