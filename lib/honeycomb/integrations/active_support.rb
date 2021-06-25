# frozen_string_literal: true

require "active_support/notifications"

module Honeycomb
  module ActiveSupport
    ##
    # Included in the configuration object to specify events that should be
    # subscribed to
    module Configuration
      attr_writer :notification_events

      def after_initialize(client)
        super(client) if defined?(super)

        events = notification_events | active_support_handlers.keys

        ActiveSupport::Subscriber.new(client: client).tap do |sub|
          events.each do |event|
            sub.subscribe(event, &method(:handle_notification_event))
          end
        end
      end

      def on_notification_event(event_name = nil, &hook)
        if event_name
          active_support_handlers[event_name] = hook
        else
          @default_handler = hook
        end
      end

      def handle_notification_event(name, span, payload)
        handler = active_support_handlers.fetch(name, default_handler)

        handler.call(name, span, payload)
      end

      def active_support_handlers
        @active_support_handlers ||= {}
      end

      def notification_events
        @notification_events ||= []
      end

      def default_handler
        @default_handler ||= lambda do |name, span, payload|
          payload.each do |key, value|
            value = value.to_unsafe_hash if value.respond_to?(:to_unsafe_hash)
            span.add_field("#{name}.#{key}", value)
          end
        end
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

Honeycomb::Configuration.prepend Honeycomb::ActiveSupport::Configuration
