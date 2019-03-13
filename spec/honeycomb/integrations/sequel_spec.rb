# frozen_string_literal: true

require "sequel"
require "honeycomb/integrations/sequel"

RSpec.describe Honeycomb::Sequel do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:db) do
    Sequel.mock.tap do |db|
      db.extension :honeycomb
      db.honeycomb_client = Honeycomb::Client.new(client: libhoney_client)
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
