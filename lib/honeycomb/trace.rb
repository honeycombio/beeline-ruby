# frozen_string_literal: true

require "forwardable"
require "securerandom"
require "honeycomb/span"

module Honeycomb
  # Represents a Honeycomb trace, which groups spans together
  class Trace
    extend Forwardable

    def_delegators :@root_span, :send

    def initialize(builder:)
      @id = SecureRandom.uuid
      @rollup_fields = Hash.new(0)
      @fields = {}
      @root_span = Span.new(trace: self, event: builder.event)
    end

    def add_field(key, value)
      @fields[key] = value
    end

    def add_rollup_field(key, value)
      @rollup_fields[key] += value
    end
  end
end
