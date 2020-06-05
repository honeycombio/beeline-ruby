# frozen_string_literal: true

require "active_support/notifications"

module Honeycomb
  module ActiveSupport
    ##
    # Included in the configuration object to specify events that should be
    # subscribed to
    module Configuration
      attr_accessor :notification_events

      def after_initialize(client)
        super(client) if defined?(super)

        events = notification_events || []
        ActiveSupport::Subscriber.new(client: client).tap do |sub|
          events.each do |event|
            sub.subscribe(event, &method(:handle_notification_event))
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
    end

    # Handles ActiveSupport::Notification subscriptions, relaying them to a
    # Honeycomb client
    class Subscriber
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

      attr_reader :key, :client, :handlers

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
