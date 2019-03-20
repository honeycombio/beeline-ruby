# frozen_string_literal: true

require "active_support/notifications"

module Honeycomb
  module ActiveSupport
    # Handles ActiveSupport::Notification subscriptions, relaying them to a
    # Honeycomb client
    class Subscriber
      attr_reader :key, :client, :events

      def initialize(client:, events:)
        @client = client
        @events = events
        @key = ["honeycomb", self.class.name, object_id].join("-")
      end

      def subscribe
        events.each do |event|
          ::ActiveSupport::Notifications.subscribe(event, self)
        end
      end

      def start(name, id, _payload)
        spans[id] << client.start_span(name: name)
      end

      def finish(name, id, payload)
        return unless (span = spans[id].pop)

        payload.each do |key, value|
          span.add_field("#{name}.#{key}", value.to_s)
        end

        span.send
      end

      def spans
        Thread.current[key] ||= Hash.new { |h, id| h[id] = [] }
      end
    end
  end
end
