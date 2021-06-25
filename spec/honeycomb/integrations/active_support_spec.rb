# frozen_string_literal: true

if defined?(Honeycomb::ActiveSupport)
  RSpec.describe Honeycomb::ActiveSupport do
    describe "custom notifications" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
        end
      end
      let(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:subscriber) do
        Honeycomb::ActiveSupport::Subscriber.new(client: client)
      end
      let(:event_name) { "honeycomb.test_event" }

      before do
        subscriber.subscribe(event_name) do |_name, span, payload|
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

    describe "custom notifications with regex" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
        end
      end
      let(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:subscriber) do
        Honeycomb::ActiveSupport::Subscriber.new(client: client)
      end
      let(:event_name) { "honeycomb.test_event" }
      before do
        subscriber.subscribe(/honeycomb/) do |_name, span, payload|
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

    describe "custom notifications with regex and string for same key" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
        end
      end
      let(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:subscriber) do
        Honeycomb::ActiveSupport::Subscriber.new(client: client)
      end
      let(:event_name) { "honeycomb.test_event" }
      before do
        [event_name, /#{event_name}/].each do |event|
          subscriber.subscribe(event) do |_name, span, payload|
            payload.each do |key, value|
              span.add_field(key, value)
            end
          end
        end

        ActiveSupport::Notifications.instrument event_name, "honeycomb" => 1 do
        end
      end

      it_behaves_like "event data", package_fields: false, additional_fields: [
        "honeycomb",
      ]

      it "sends two events" do
        expect(libhoney_client.events.size).to eq 2
      end
    end

    describe "custom notifications with custom default handler hook" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.notification_events = [event_name]
          config.on_notification_event do |_name, span, _payload|
            span.add_field("off_the_hook", "bees")
          end
        end
      end
      let!(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:event_name) { "honeycomb.test_event" }

      before do
        ActiveSupport::Notifications.instrument event_name, "honeycomb" => 1 do
        end
      end

      it_behaves_like "event data", package_fields: false, additional_fields: [
        "off_the_hook",
      ]

      it "sends a single event" do
        expect(libhoney_client.events.size).to eq 1
      end
    end

     describe "custom notifications with event specific handler hook" do
      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.notification_events = ["honeycomb.nonspecific_event"]
          config.on_notification_event("honeycomb.test_event") do |name, span, _payload|
            span.add_field("the_hive", "queen")
          end
        end
      end
      let!(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:event_name) { "honeycomb.test_event" }

      before do
        ActiveSupport::Notifications.instrument event_name, "honeycomb" => 1 do
        end
      end

      it_behaves_like "event data", package_fields: false, additional_fields: [
        "the_hive",
      ]

      it "uses the default handler for events without a specific handler" do
        ActiveSupport::Notifications.instrument "honeycomb.nonspecific_event", "honeycomb" => 1 do
        end

        this_event = libhoney_client.events.find { |e| e.data["name"] == "honeycomb.nonspecific_event" }

        expect(this_event).not_to be nil
        expect(this_event.data["honeycomb.nonspecific_event.honeycomb"]).to eq 1
      end

      context "with a custom default handler" do
        let(:configuration) do
          Honeycomb::Configuration.new.tap do |config|
            config.client = libhoney_client
            config.notification_events = ["honeycomb.nonspecific_event"]
            config.on_notification_event do |_name, span, _payload|
              span.add_field("the_hive", "bees")
            end

            config.on_notification_event("honeycomb.test_event") do |name, span, _payload|
              span.add_field("the_hive", "queen")
            end
          end
        end

        before do
          ActiveSupport::Notifications.instrument "honeycomb.nonspecific_event", "honeycomb" => 1 do
          end
        end

        it_behaves_like "event data", package_fields: false, additional_fields: [
          "the_hive"
        ]

        it "uses the new default handler for events without a specific handler" do
          expect(event_data).to match_array(
            [
              hash_including("name" => "honeycomb.nonspecific_event", "the_hive" => "bees"),
              hash_including("name" => "honeycomb.test_event", "the_hive" => "queen")
            ]
          )
        end
      end
    end

    describe "pass ActionController::Parameters as hash" do
      require "action_controller"

      let(:libhoney_client) { Libhoney::TestClient.new }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.notification_events = [event_name]
        end
      end
      let!(:client) { Honeycomb::Client.new(configuration: configuration) }
      let(:event_data) { libhoney_client.events.map(&:data) }
      let(:event_name) { "hny.test_event" }

      let(:params) { ActionController::Parameters.new(a: "1", b: "2") }
      before do
        ActiveSupport::Notifications.instrument(event_name,
                                                "params" => params) do
        end
      end

      let(:event) { event_data.last }
      let(:fields) { { "hny.test_event.params" => { "a" => "1", "b" => "2" } } }

      it "sends the expected fields on success" do
        expect(event).to include(fields)
      end

      it "sends a single event" do
        expect(libhoney_client.events.size).to eq 1
      end
    end
  end
end
