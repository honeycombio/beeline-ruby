# frozen_string_literal: true

require "securerandom"
require "forwardable"
require "honeycomb/propagation"
require "honeycomb/deterministic_sampler"
require "honeycomb/rollup_fields"

module Honeycomb
  # Represents a Honeycomb span, which wraps a Honeycomb event and adds specific
  # tracing functionality
  class Span
    include PropagationSerializer
    include DeterministicSampler
    include RollupFields
    extend Forwardable

    def_delegators :@event, :add_field, :add
    def_delegator :@trace, :add_field, :add_trace_field

    attr_reader :id, :trace

    def initialize(trace:,
                   builder:,
                   context:,
                   **options)
      @id = SecureRandom.uuid
      @context = context
      @context.current_span = self
      @builder = builder
      @event = builder.event
      @trace = trace
      @children = []
      @sent = false
      @started = clock_time
      parse_options(**options)
    end

    def parse_options(parent_id: nil,
                      is_root: parent_id.nil?,
                      sample_hook: nil,
                      presend_hook: nil,
                      **_options)
      @parent_id = parent_id
      @is_root = is_root
      @presend_hook = presend_hook
      @sample_hook = sample_hook
    end

    def create_child
      self.class.new(trace: trace,
                     builder: builder,
                     context: context,
                     parent_id: id,
                     sample_hook: sample_hook,
                     presend_hook: presend_hook).tap do |c|
        children << c
      end
    end

    def send
      return if sent?

      send_internal
    end

    protected

    def send_by_parent
      return if sent?

      add_field "meta.sent_by_parent", true
      send_internal
    end

    private

    attr_reader :event,
                :parent_id,
                :children,
                :builder,
                :context,
                :presend_hook,
                :sample_hook

    def sent?
      @sent
    end

    def root?
      @is_root
    end

    def send_internal
      add_field "duration_ms", duration_ms
      add_field "trace.trace_id", trace.id
      add_field "trace.span_id", id
      add_field "meta.span_type", span_type
      parent_id && add_field("trace.parent_id", parent_id)
      add rollup_fields
      add trace.fields
      span_type == "root" && add(trace.rollup_fields)
      send_children
      sample = true
      if sample_hook.nil?
        sample = should_sample(event.sample_rate, trace.id)
      else
        sample, event.sample_rate = sample_hook.call(event.data)
      end

      if sample
        presend_hook && presend_hook.call(event.data)
        event.send_presampled
      end
      @sent = true
      context.span_sent(self)
    end

    def send_children
      children.each do |child|
        child.send_by_parent
      end
    end

    def duration_ms
      (clock_time - @started) * 1000
    end

    def clock_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def span_type
      if root?
        parent_id.nil? ? "root" : "subroot"
      elsif children.empty?
        "leaf"
      else
        "mid"
      end
    end
  end
end
