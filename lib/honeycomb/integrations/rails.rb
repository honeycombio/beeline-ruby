# frozen_string_literal: true

require "rails"

module Honeycomb
  # Automatically capture rack requests and create a trace
  class Rails < ::Rails::Railtie
    DEFAULT_NOTIFICATION_EVENTS = %w[
      sql.active_record
      render_template.action_view
      render_partial.action_view
      render_collection.action_view
      process_action.action_controller
      send_file.action_controller
      send_data.action_controller
      deliver.action_mailer
    ].freeze

    config.honeycomb = ActiveSupport::OrderedOptions.new

    initializer "honeycomb.configure" do |app|
      Honeycomb.configure do |config|
        config.write_key = app.config.honeycomb[:write_key]
        config.dataset = app.config.honeycomb[:dataset]
        config.service_name = app.config.honeycomb[:service_name]
      end
      # what location should we insert the middleware at?
      app.config.middleware.use Honeycomb::Rack, client: Honeycomb.client

      events = app.config.honeycomb[:notification_events] ||
               DEFAULT_NOTIFICATION_EVENTS

      subscribe_to_events(client: Honeycomb.client, events: events)
    end

    def subscribe_to_events(client:, events:)
      Subscriber.new(client: client).tap do |subscriber|
        events.each do |event|
          ActiveSupport::Notifications.subscribe(event, subscriber)
        end
      end
    end

    # Handles ActiveSupport::Notification subscriptions, relaying them to a
    # Honeycomb client
    class Subscriber
      attr_reader :key, :client

      def initialize(client:)
        @client = client
        @key = ["honeycomb", self.class.name, object_id].join("-")
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
