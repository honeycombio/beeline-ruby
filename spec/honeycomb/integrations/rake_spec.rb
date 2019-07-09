# frozen_string_literal: true

if defined?(Honeycomb::Rake)
  RSpec.describe Honeycomb::Rake do
    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:event_data) { libhoney_client.events.map(&:data) }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }

    before do
      other_rake = Rake.with_application do |app|
        app.add_import "spec/support/test_tasks.rake"
        app.load_rakefile
      end
      other_rake.honeycomb_client = client
      other_rake.invoke_task("test:perform")
    end

    it "sends the two events" do
      expect(libhoney_client.events.size).to eq 2
    end

    it_behaves_like "event data"
  end
end
