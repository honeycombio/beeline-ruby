# frozen_string_literal: true

# TODO consider doing something with SCHEMA
module Honeycomb
  module ActiveSupport
    module Standardize
      class ProcessActionActionController < Base
        def self.canonicalize(name, payload)
          if payload[:controller] && payload[:action]
            return "#{payload[:controller]} #{payload[:action]}"
          end
          name
        end
      end
    end
  end
end
