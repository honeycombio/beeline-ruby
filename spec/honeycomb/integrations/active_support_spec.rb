# frozen_string_literal: true

if defined?(Honeycomb::ActiveSupport)
  RSpec.describe Honeycomb::ActiveSupport do
    describe "custom notifications" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:client) { Honeycomb::Client.new(client: libhoney_client) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:subscriber) do
        Honeycomb::ActiveSupport::Subscriber.new(client: client)
      end
      let(:event_name) { "honeycomb.test_event" }

      before do
        subscriber.subscribe(event_name) do |span, payload|
          payload.each do |key, value|
            span.add_field(key, value)
          end
        end

        ActiveSupport::Notifications.instrument event_name, "honeycomb" => 1 do
        end
      end

      it_behaves_like "event data", package_fields: false, additional_fields: [
        "honeycomb",
      ]

      it "sends a single event" do
        expect(libhoney_client.events.size).to eq 1
      end
    end
  end
end
