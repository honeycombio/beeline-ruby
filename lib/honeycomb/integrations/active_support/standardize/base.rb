# frozen_string_literal: true

require 'singleton'

# TODO
# - consider adding some kind of event skip functionality
module Honeycomb
  module ActiveSupport
    module Standardize
      class Base
        include Singleton

        def self.canonicalize(name, payload)
          return name
        end

        def self.add_fields(span, name, payload)
          span.add_field("name.type", name.to_s)
          payload.each do |key, value|
            span.add_field("#{name}.#{key}", value.to_s)
          end
        end
      end
    end
  end
end
