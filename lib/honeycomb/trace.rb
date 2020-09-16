# frozen_string_literal: true

require "forwardable"
require "securerandom"
require "honeycomb/span"
require "honeycomb/propagation"
require "honeycomb/rollup_fields"

module Honeycomb
  # Represents a Honeycomb trace, which groups spans together
  class Trace
    include PropagationParser
    include RollupFields
    extend Forwardable

    def_delegators :@root_span, :send

    attr_reader :id, :fields, :root_span

    def initialize(
      builder:, context:,
      serialized_trace: nil,
      propagation_context: nil,
      **options
    )
      # if a propagation context hash was successfully created, use that
      # otherwise fall back to previous behavior of parsing a string
      if propagation_context
        trace_id, parent_span_id, trace_fields, dataset =
          propagation_context
      else
        trace_id, parent_span_id, trace_fields, dataset =
          parse serialized_trace
      end
      dataset && builder.dataset = dataset
      @id = trace_id || generate_trace_id
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

    private

    INVALID_TRACE_ID = ("00" * 16)

    def generate_trace_id
      loop do
        id = SecureRandom.hex(16)
        return id unless id == INVALID_TRACE_ID
      end
    end
  end
end
