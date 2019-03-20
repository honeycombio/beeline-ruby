# frozen_string_literal: true

require "rails"
require "honeycomb/integrations/active_support"

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

    config.honeycomb = ::ActiveSupport::OrderedOptions.new

    initializer "honeycomb.configure" do |app|
      Honeycomb.configure do |config|
        config.write_key = app.config.honeycomb[:write_key]
        config.dataset = app.config.honeycomb[:dataset]
        config.service_name = app.config.honeycomb[:service_name]
        config.client = app.config.honeycomb[:client]
      end
    end

    initializer "honeycomb.install_middleware" do |app|
      # what location should we insert the middleware at?
      begin
        app.config.middleware.insert_before(
          ::Rails::Rack::Logger,
          Honeycomb::Rack,
          client: Honeycomb.client,
        )
      rescue StandardError
        app.config.middleware.use Honeycomb::Rack, client: Honeycomb.client
      end
    end

    initializer "honeycomb.subscribe" do |app|
      events = app.config.honeycomb[:notification_events] ||
               DEFAULT_NOTIFICATION_EVENTS
      ActiveSupport::Subscriber.new(client: Honeycomb.client).tap do |sub|
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
end
