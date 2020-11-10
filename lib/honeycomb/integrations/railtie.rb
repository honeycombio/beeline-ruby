# frozen_string_literal: true

require "rails/railtie"
require "honeycomb/integrations/rails"

module Honeycomb
  # Automatically capture rack requests and create a trace
  class Railtie < ::Rails::Railtie
    def self.insert_middleware(app, client)
      app.config.middleware.insert_before(
        ActionDispatch::ShowExceptions,
        Honeycomb::Rails::Middleware,
        client: client,
      )
    end

    initializer("honeycomb.install_middleware",
                after: :load_config_initializers) do |app|
      self.class.insert_middleware(app, Honeycomb.client) if Honeycomb.client
    end
  end
end
