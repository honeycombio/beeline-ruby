# frozen_string_literal: true

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
        # calling request.params will blow up if raw_post is nil,
        # or if the request content-type is JSON but the request
        # body is not valid JSON.
        params = {}
        begin
          params = request.params
        rescue StandardError => e
          yield "request.failed_to_read_params", e.message
        end

        yield "request.controller", params[:controller]
        yield "request.action", params[:action]

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
end
