# frozen_string_literal: true

require "forwardable"
require "honeycomb/beeline/version"
require "honeycomb/configuration"
require "honeycomb/context"

module Honeycomb
  # The Honeycomb Beeline client
  class Client
    extend Forwardable

    attr_reader :libhoney

    def_delegators :@context, :current_span, :current_trace

    def initialize(configuration:)
      @libhoney = configuration.client
      # attempt to set the user_agent_addition, this will only work if the
      # client has not sent an event prior to being passed in here. This should
      # be most cases
      @libhoney.instance_variable_set(:@user_agent_addition,
                                      Honeycomb::Beeline::USER_AGENT_SUFFIX)
      @libhoney.add_field "meta.beeline_version", Honeycomb::Beeline::VERSION
      @libhoney.add_field "meta.local_hostname", configuration.host_name

      integrations = Honeycomb.integrations_to_load
      @libhoney.add_field "meta.instrumentations_count", integrations.count
      @libhoney.add_field "meta.instrumentations", integrations.map(&:to_s).to_s

      # maybe make `service_name` a required parameter
      @libhoney.add_field "service_name", configuration.service_name
      @context = Context.new

      @additional_trace_options = {
        presend_hook: configuration.presend_hook,
        sample_hook: configuration.sample_hook,
        parser_hook: configuration.http_trace_parser_hook,
        propagation_hook: configuration.http_trace_propagation_hook,
      }

      configuration.after_initialize(self)

      at_exit do
        libhoney.close
      end
    end

    def start_span(name:, serialized_trace: nil, **fields)
      if context.current_trace.nil?
        Trace.new(serialized_trace: serialized_trace,
                  builder: libhoney.builder,
                  context: context,
                  **@additional_trace_options)
      else
        context.current_span.create_child
      end

      current_span = context.current_span

      fields.each do |key, value|
        current_span.add_field(key, value)
      end

      current_span.add_field("name", name)

      return current_span unless block_given?

      begin
        yield current_span
      rescue StandardError => e
        current_span.add_field("error", e.class.name)
        current_span.add_field("error_detail", e.message)
        raise e
      ensure
        current_span.send
      end
    end

    def add_field(key, value)
      return if context.current_span.nil?

      context.current_span.add_field("app.#{key}", value)
    end

    def add_field_to_trace(key, value)
      return if context.current_span.nil?

      context.current_span.trace.add_field("app.#{key}", value)
    end

    def with_field(key)
      yield.tap { |value| add_field(key, value) }
    end

    def with_trace_field(key)
      yield.tap { |value| add_field_to_trace(key, value) }
    end

    private

    attr_reader :context
  end
end
