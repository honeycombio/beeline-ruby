require 'active_record'

require 'support/db'

module TestDB
  module ActiveRecord
    class << self
      attr_reader :connection_pool

      def config
        @config ||= YAML.load_file("#{DB_DIR}/config-activerecord.yml")
      end

      def establish_connection
        @connection_pool = ::ActiveRecord::Base.establish_connection(config.fetch('test'))
      end

      def disconnect
        @connection_pool.disconnect
      end
    end
  end
end

class Animal < ActiveRecord::Base
  validates_presence_of :species
end

RSpec.configure do |config|
  config.before(:suite) do
    TestDB::ActiveRecord.establish_connection
  end
  config.after(:suite) do
    TestDB::ActiveRecord.disconnect
  end

  config.before(:example) do
    ActiveRecord::Base.connection.begin_transaction
    $fakehoney.reset # get rid of the BEGIN event
  end
  config.after(:example) do
    ActiveRecord::Base.connection.rollback_transaction
  end
end
