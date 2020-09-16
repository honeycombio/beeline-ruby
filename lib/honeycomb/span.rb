# frozen_string_literal: true

require "forwardable"
require "securerandom"
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

    attr_reader :id, :trace, :propagation_hook

    def initialize(trace:,
                   builder:,
                   context:,
                   **options)
      @id = generate_span_id
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

    def parse_options(parent: nil, # rubocop:disable Metrics/ParameterLists
                      parent_id: nil,
                      is_root: parent_id.nil?,
                      sample_hook: nil,
                      presend_hook: nil,
                      propagation_hook: nil,
                      **_options)
      @parent = parent
      # parent_id should be removed in the next major version bump. It has been
      # replaced with passing the actual parent in. This is kept for backwards
      # compatability
      @parent_id = parent_id
      @is_root = is_root
      @presend_hook = presend_hook
      @sample_hook = sample_hook
      @propagation_hook = propagation_hook
    end

    def create_child
      self.class.new(trace: trace,
                     builder: builder,
                     context: context,
                     parent: self,
                     parent_id: id,
                     sample_hook: sample_hook,
                     propagation_hook: propagation_hook,
                     presend_hook: presend_hook).tap do |c|
        children << c
      end
    end

    def send
      return if sent?

      send_internal
    end

    # for passing a propagation context object for a current Span
    def propagation_context_from_span
      trace_id = trace.id
      parent_span_id = id
      trace_fields = trace.fields
      dataset = builder.dataset

      [trace_id, parent_span_id, trace_fields, dataset]
    end

    protected

    def send_by_parent
      return if sent?

      add_field "meta.sent_by_parent", true
      send_internal
    end

    def remove_child(child)
      children.delete child
    end

    private

    INVALID_SPAN_ID = ("00" * 8)

    attr_reader :event,
                :parent,
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
      add_additional_fields
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

      parent && parent.remove_child(self)
    end

    def add_additional_fields
      add_field "duration_ms", duration_ms
      add_field "trace.trace_id", trace.id
      add_field "trace.span_id", id
      add_field "meta.span_type", span_type
      parent_id && add_field("trace.parent_id", parent_id)
      add rollup_fields
      add trace.fields
      span_type == "root" && add(trace.rollup_fields)
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

    def generate_span_id
      loop do
        id = SecureRandom.hex(8)
        return id unless id == INVALID_SPAN_ID
      end
    end
  end
end
