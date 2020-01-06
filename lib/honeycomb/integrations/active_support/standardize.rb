# frozen_string_literal: true

require "active_support/inflector"

Dir["#{File.dirname(__FILE__)}/standardize/*.rb"].each { |f| require f }

# For how to canonicalize various notifications, read
# https://guides.rubyonrails.org/active_support_instrumentation.html

module Honeycomb
  module ActiveSupport
    module Standardize
      def self.add_fields(span, name, payload)
        module_for(name).add_fields(span, name, payload)
      end


      def self.canonicalize(notification_name, payload)
        m = methodname(notification_name, "name")
        if methods.include? m.to_sym
          return send(m, notification_name, payload)
        else
          return notification_name
        end
      end

      def self.add_fields(span, notification_name, payload)
        span.add_field("name.type", name.to_s)

        m = methodname(notification_name, "add_fields")
        if methods.include? m.to_sym
          return send(m, notification_name, payload)
        else
          payload.each do |key, value|
            span.add_field("#{name}.#{key}", value.to_s)
          end
        end
      end


      private

      def self.methodname(notification_name, prefix)
        prefix + "_" + notification_name.gsub(".", "_").downcase
      end

      def self.name_sql_active_record(notification_name, payload)
        return payload[:name] if payload[:name]
        notification_name
      end


      def self.name_process_action_action_controller(notification_name, payload)
        if payload[:controller] && payload[:action]
          return "#{payload[:controller]} #{payload[:action]}"
        end
        notification_name
      end

      def self.name_start_processing_action_controller(notification_name, payload)
        if payload[:controller] && payload[:action]
          return #{payload[:controller]} #{payload[:action]}"
        end
        notification_name
      end

    end
  end
end
