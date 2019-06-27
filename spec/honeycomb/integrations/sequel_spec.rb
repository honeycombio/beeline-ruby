# frozen_string_literal: true

if defined?(Honeycomb::Sequel)
  RSpec.describe Honeycomb::Sequel do
    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }

    let(:db) do
      Sequel.mock.tap do |db|
        db.extension :honeycomb
        db.honeycomb_client = client
      end
    end

    before do
      exec_sql("SELECT * FROM items")
    end

    def exec_sql(sql)
      db[sql].all
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data"
  end
end
