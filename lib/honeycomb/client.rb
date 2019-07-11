# frozen_string_literal: true

require "honeycomb/beeline/version"
require "honeycomb/configuration"
require "honeycomb/context"

module Honeycomb
  # The Honeycomb Beeline client
  class Client
    def initialize(configuration:)
      @client = configuration.client
      # attempt to set the user_agent_addition, this will only work if the
      # client has not sent an event prior to being passed in here. This should
      # be most cases
      @client.instance_variable_set(:@user_agent_addition,
                                    Honeycomb::Beeline::USER_AGENT_SUFFIX)
      @client.add_field "meta.beeline_version", Honeycomb::Beeline::VERSION
      @client.add_field "meta.local_hostname", configuration.host_name

      # maybe make `service_name` a required parameter
      @client.add_field "service_name", configuration.service_name
      @context = Context.new

      @additional_trace_options = {
        presend_hook: configuration.presend_hook,
        sample_hook: configuration.sample_hook,
      }

      configuration.after_initialize(self)

      at_exit do
        client.close
      end
    end

    def start_span(name:, serialized_trace: nil, **fields)
      if context.current_trace.nil?
        Trace.new(serialized_trace: serialized_trace,
                  builder: client.builder,
                  context: context,
                  **@additional_trace_options)
      else
        context.current_span.create_child
      end

      fields.each do |key, value|
        context.current_span.add_field(key, value)
      end

      context.current_span.add_field("name", name)

      if block_given?
        begin
          yield context.current_span
        rescue StandardError => e
          context.current_span.add_field("request.error", e.class.name)
          context.current_span.add_field("request.error_detail", e.message)
          raise e
        ensure
          context.current_span.send
        end
      else
        context.current_span
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

    private

    attr_reader :client, :context
  end
end
