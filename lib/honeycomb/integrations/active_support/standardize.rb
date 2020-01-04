# frozen_string_literal: true

require "active_support/inflector"

Dir["#{File.dirname(__FILE__)}/standardize/*.rb"].each { |f| require f }

# For how to canonicalize various notifications, read
# https://guides.rubyonrails.org/active_support_instrumentation.html

module Honeycomb
  module ActiveSupport
    module Standardize
      def self.canonicalize(name, payload)
        module_for(name).canonicalize(name, payload)
      end

      def self.add_fields(span, name, payload)
        module_for(name).add_fields(span, name, payload)
      end

      private

      def self.canonicalize_name(name)
        "Honeycomb::ActiveSupport::Standardize::#{name.gsub(".", "_").camelcase}"
      end

      def self.module_for(name)
        canonicalize_name(name).constantize
      rescue NameError
        Honeycomb::ActiveSupport::Standardize::Base
      end
    end
  end
end
