# frozen_string_literal: true

require "forwardable"

module Honeycomb
  # Represents a Honeycomb span, which wraps a Honeycomb event and adds specific
  # tracing functionality
  class Span
    extend Forwardable

    def_delegators :@event, :add_field, :add

    attr_reader :id, :trace

    def initialize(trace:,
                   builder:,
                   context:,
                   parent_id: nil,
                   is_root: parent_id.nil?)
      @id = SecureRandom.uuid
      @context = context
      @context.current_span = self
      @builder = builder
      @event = builder.event
      @trace = trace
      @parent_id = parent_id
      @is_root = is_root
      @rollup_fields = Hash.new(0)
      @children = []
      @sent = false
    end

    def add_rollup_field(key, value)
      trace.add_rollup_field(key, value)
      rollup_fields[key] += value
    end

    def add_trace_field(key, value)
      trace.add_field(key, value)
    end

    def create_child
      self.class.new(trace: trace,
                     builder: builder,
                     context: context,
                     parent_id: id).tap do |c|
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

    attr_reader :rollup_fields,
                :event,
                :parent_id,
                :children,
                :builder,
                :context

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
      event.send
      @sent = true
      context.span_sent(self)
    end

    def send_children
      children.each do |child|
        child.send_by_parent
      end
    end

    def start_time
      event.timestamp
    end

    def duration_ms
      (Time.now.utc - start_time) * 1000
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
