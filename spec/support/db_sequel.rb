require 'sequel'

require 'support/db'

module TestDB
  module Sequel
    class << self
      attr_reader :db

      def config
        @config ||= YAML.parse_file("#{DB_DIR}/config-sequel.yml").to_ruby
      end

      def connect!
        @db ||= ::Sequel.connect(**config)
      end

      def disconnect!
        @db.disconnect if @db
        @db = nil
      end

      def Animals
        @animals ||= db[:animals]
      end
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    TestDB::Sequel.connect!
  end
  config.after(:suite) do
    TestDB::Sequel.disconnect!
  end

  config.before(:example) do
    TestDB::Sequel.db.run 'BEGIN'

    $fakehoney.reset # get rid of the BEGIN events
  end
  config.after(:example) do
    TestDB::Sequel.db.run 'ROLLBACK'
  end
end
