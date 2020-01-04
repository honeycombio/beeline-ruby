# frozen_string_literal: true

# TODO consider doing something with SCHEMA
module Honeycomb
  module ActiveSupport
    module Standardize
      class SqlActiveRecord < Base
        def self.canonicalize(name, payload)
          return payload[:name] if payload[:name]
          name
        end
      end
    end
  end
end
