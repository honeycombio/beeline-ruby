# frozen_string_literal: true

require "sequel"

module Honeycomb
  # Wrap sequel commands in a span
  module Sequel
    attr_accessor :honeycomb_client

    def log_connection_yield(sql, conn, args = nil)
      honeycomb_client.start_span(name: sql.sub(/\s+.*/, "").upcase) do |span|
        span.add_field "type", "db"
        span.add_field "db.sql", sql
        super
      end
    end
  end
end

Sequel::Database.register_extension(:honeycomb, Honeycomb::Sequel)
