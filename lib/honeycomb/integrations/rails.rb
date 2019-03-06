# frozen_string_literal: true

require "rails"

module Honeycomb
  # Automatically capture rack requests and create a trace
  class Rails < ::Rails::Railtie
    NOTIFICATION_EVENTS = %w[
      sql.active_record
      render_template.action_view
      send_file.action_controller
      send_data.action_controller
      deliver.action_mailer
    ].freeze

    config.honeycomb = ActiveSupport::OrderedOptions.new

    initializer "honeycomb.configure" do |app|
      Honeycomb.configure do |config|
        config.write_key = app.config.honeycomb[:write_key]
      end
      # what location should we insert the middleware at?
      app.config.middleware.use Honeycomb::Rack, client: Honeycomb.client

      subscribe_to_events(Honeycomb.client)
    end

    def subscribe_to_events(client:)
      subscriber = Subscriber.new(client: client)
      NOTIFICATION_EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe(event, subscriber)
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
