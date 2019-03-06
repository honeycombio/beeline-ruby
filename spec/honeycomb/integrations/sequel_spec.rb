# frozen_string_literal: true

require "sequel"
require "honeycomb/integrations/sequel"

RSpec.describe Honeycomb::Sequel do
  let(:db) do
    Sequel.mock.tap do |database|
      database.extension :honeycomb
    end
  end

  def exec_sql(sql)
    db[sql].all
  end

  it "works" do
    db.honeycomb_client = Honeycomb::Client.new(client: Libhoney::LogClient.new)
    exec_sql("SELECT * FROM items")
  end
end
