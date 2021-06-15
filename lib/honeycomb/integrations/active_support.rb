# frozen_string_literal: true

require "active_support/notifications"

module Honeycomb
  module ActiveSupport
    ##
    # Included in the configuration object to specify events that should be
    # subscribed to
    module Configuration
      attr_accessor :notification_events, :customized_event_handlers

      def after_initialize(client)
        super(client) if defined?(super)

        events = notification_events || []
        customized_events = customized_event_handlers || {}

        ActiveSupport::Subscriber.new(client: client).tap do |sub|
          events.each do |event|
            sub.subscribe(event, &method(:handle_notification_event))
          end

          customized_event_handlers.each do |event, handler|
            if sub.handlers.key?(event)
              raise "Cannot use generic notification handling and set a custom handler for the same event" \
                    "Please remove '#{event}' from the `notification_events` list as configured or" \
                    "remove the `register_notification_handler` call including it."
            end

            sub.subscribe(event, &handler)
          end
        end
      end

      def on_notification_event(&hook)
        if block_given?
          @on_notification_event = hook
        else
          @on_notification_event
        end
      end

      def register_notification_handler(name, &block)
        raise "Must provide a block to handle '#{name}' events" unless block_given?
        raise "Named notification handlers must accept 3 arguments, given block accepts #{block.arity}" unless block.arity == 3

        self.customized_event_handlers ||= {}

        raise "Duplicate named handler registered for '#{name}'" if customized_event_handlers.key?(name)
        customized_event_handlers[name] = block
      end

      def handle_notification_event(name, span, payload)
        if on_notification_event
          on_notification_event.call(name, span, payload)
        else
          payload.each do |key, value|
            # Make ActionController::Parameters parseable by libhoney.
            value = value.to_unsafe_hash if value.respond_to?(:to_unsafe_hash)
            span.add_field("#{name}.#{key}", value)
          end
        end
      end

      private

      def named_notification_event_handlers
        @named_notification_event_handlers ||= Hash.new { |h, k| h[k] = on_notification_event }
      end
    end

    # Handles ActiveSupport::Notification subscriptions, relaying them to a
    # Honeycomb client
    class Subscriber
      attr_reader :handlers

      def initialize(client:)
        @client = client
        @handlers = {}
        @key = ["honeycomb", self.class.name, object_id].join("-")
      end

      def subscribe(event, &block)
        return unless block_given?

        handlers[event] = block
        ::ActiveSupport::Notifications.subscribe(event, self)
      end

      def start(name, id, _payload)
        spans[id] << client.start_span(name: name)
      end

      def finish(name, id, payload)
        return unless (span = spans[id].pop)

        handler_for(name).call(name, span, payload)

        span.send
      end

      private

      attr_reader :key, :client

      def spans
        Thread.current[key] ||= Hash.new { |h, id| h[id] = [] }
      end

      def handler_for(name)
        handlers.fetch(name) do
          handlers[
            handlers.keys.detect do |key|
              key.is_a?(Regexp) && key =~ name
            end
          ]
        end
      end
    end
  end
end

Honeycomb::Configuration.include Honeycomb::ActiveSupport::Configuration
