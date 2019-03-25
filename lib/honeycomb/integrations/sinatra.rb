# frozen_string_literal: true

require "sinatra"
require "honeycomb/integrations/rack"

module Honeycomb
  # Add Sinatra specific information to the Honeycomb::Rack middleware
  module Sinatra
    def add_package_information(env)
      yield "meta.package", "sinatra"
      yield "meta.package_version", ::Sinatra::VERSION

      yield "request.route", env["sinatra.route"]
    end
  end
end

Honeycomb::Rack.prepend Honeycomb::Sinatra
