# frozen_string_literal: true

require "forwardable"
require "honeycomb/beeline/version"
require "honeycomb/configuration"
require "honeycomb/context"
require "honeycomb/propagation/honeycomb"

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

    def propagation_context_from_req(env:)
      # set default parser to honeycomb
      parser = Honeycomb::HoneycombPropagation::Parser.new
      parser_hook = lambda do |req|
        parser.http_trace_parser_hook(req)
      end

      # if there's a custom hook, overwrite parser_hook with it
      unless @additional_trace_options[:parser_hook].nil?
        parser_hook = lambda do |req|
          @additional_trace_options[:parser_hook].call(req)
        end
      end

      parser_hook.call(env)
    end

    def headers_from_propagation_context(propagation_context)
      # set default propagator to honeycomb
      propagator = Honeycomb::HoneycombPropagation::Propagator.new
      propagation_hook = lambda do |context|
        propagator.http_trace_propagation_hook(context)
      end

      # if there's a custom hook, overwrite propagation_hook with it
      unless @additional_trace_options[:propagation_hook].nil?
        propagation_hook = lambda do |context|
          @additional_trace_options[:propagation_hook].call(context)
        end
      end

      propagation_hook.call(propagation_context)
    end

    def start_span(
      name:, serialized_trace: nil, propagation_context: nil,
      **fields
    )
      if context.current_trace.nil?
        Trace.new(serialized_trace: serialized_trace,
                  builder: libhoney.builder,
                  context: context,
                  propagation_context: propagation_context,
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

    private

    attr_reader :context
  end
end
