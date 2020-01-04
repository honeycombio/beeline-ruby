# frozen_string_literal: true

# TODO
# - consider adding some kind of event skip functionality
module Honeycomb
  module ActiveSupport
    module Standardize
      module Base
        def self.name(name, payload)
          return name
        end

        def self.fields(span, name, payload)
          span.add_field("name.type", name.to_s)
          payload.each do |key, value|
            span.add_field("#{name}.#{key}", value.to_s)
          end
        end
      end
    end
  end
end
