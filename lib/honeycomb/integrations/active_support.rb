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
            sub.subscribe(event) do |span, payload|
              payload.each do |key, value|
                span.add_field("#{event}.#{key}", value.to_s)
              end
            end
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

        handlers[name].call(span, payload)

        span.send
      end

      private

      attr_reader :key, :client, :handlers

      def spans
        Thread.current[key] ||= Hash.new { |h, id| h[id] = [] }
      end
    end
  end
end

Honeycomb::Configuration.include Honeycomb::ActiveSupport::Configuration
