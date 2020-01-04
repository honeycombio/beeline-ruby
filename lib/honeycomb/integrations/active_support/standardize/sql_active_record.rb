# frozen_string_literal: true

# TODO consider doing something with SCHEMA
module Honeycomb
  module ActiveSupport
    module Standardize
      module SqlActiveRecord
        def self.name(name, payload)
          return payload[:name] if payload[:name]
          name
        end
      end
    end
  end
end
