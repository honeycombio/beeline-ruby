# frozen_string_literal: true

require "rails/railtie"
require "honeycomb/integrations/active_support"
require "honeycomb/integrations/rack"
require "honeycomb/integrations/warden"

module Honeycomb
  # Rails specific methods for building middleware
  module Rails
    def add_package_information(env)
      yield "meta.package", "rails"
      yield "meta.package_version", ::Rails::VERSION::STRING

      ::ActionDispatch::Request.new(env).tap do |request|
        yield "request.controller", request.params[:controller]
        yield "request.action", request.params[:action]

        break unless request.respond_to? :routes
        break unless request.routes.respond_to? :router

        found_route = false
        request.routes.router.recognize(request) do |route, _|
          break if found_route

          found_route = true
          yield "request.route", "#{env['REQUEST_METHOD']} #{route.path.spec}"
        end
      end
    end

    # Rails middleware
    class Middleware
      include Rack
      include Warden
      include Rails
    end
  end

  # Automatically capture rack requests and create a trace
  class Railtie < ::Rails::Railtie
    initializer("honeycomb.install_middleware",
                after: :load_config_initializers) do |app|
      if Honeycomb.client
        # what location should we insert the middleware at?
        app.config.middleware.insert_before(
          ::Rails::Rack::Logger,
          Honeycomb::Rails::Middleware,
          client: Honeycomb.client,
        )
      end
    end
  end
end
