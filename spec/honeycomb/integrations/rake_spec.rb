# frozen_string_literal: true

if defined?(Honeycomb::Rake)
  RSpec.describe Honeycomb::Rake do
    # Each example is run within an isolated Rake application.
    around { |ex| Rake.with_application(&ex) }

    # Each example loads the same shared Rakefile.
    before { Rake.load_rakefile("spec/support/test_tasks.rake") }

    let(:client) do
      config = Honeycomb::Configuration.new
      config.client = Libhoney::TestClient.new
      Honeycomb::Client.new(configuration: config)
    end

    let(:custom) do
      config = Honeycomb::Configuration.new
      config.client = Libhoney::TestClient.new
      Honeycomb::Client.new(configuration: config)
    end

    let(:event_data) { client.libhoney.events.map(&:data) }

    context "when Honeycomb is not configured" do
      before { allow(Honeycomb).to receive(:client).and_return(nil) }

      it "does not send event data" do
        expect { Rake::Task["test:event_data"].invoke }.not_to raise_error
        expect(event_data).to be_empty
      end

      it "can use a custom Honeycomb client on the application level" do
        Rake.application.honeycomb_client = client
        Rake::Task["test:client:custom"].invoke
        names = event_data.map { |event| event["name"] }
        expect(names).to eq ["rake.test:client:default", "rake.test:client:custom"]
      end

      it "can use a custom Honeycomb client on the task level" do
        Rake::Task["test:client:custom"].honeycomb_client = client
        Rake::Task["test:client:custom"].invoke
        names = event_data.map { |event| event["name"] }
        expect(names).to eq ["rake.test:client:custom"]
      end
    end

    context "when Honeycomb is configured" do
      before { allow(Honeycomb).to receive(:client).and_return(client) }

      it_behaves_like "event data" do
        before { Rake::Task["test:event_data"].invoke }
      end

      it "sets the name field" do
        Rake::Task["test:name"].invoke
        expect(event_data.count).to be 1
        aggregate_failures do
          event = event_data.first
          expect(event).to include("name" => "rake.test:name")
          expect(event).not_to include("rake.description", "rake.arguments")
        end
      end

      it "sets the rake.description field" do
        Rake::Task["test:description"].invoke
        expect(event_data.count).to be 1
        aggregate_failures do
          event = event_data.first
          expect(event).to include(
            "name" => "rake.test:description",
            "rake.description" => "this is a description",
          )
          expect(event).not_to include("rake.arguments")
        end
      end

      it "sets the rake.arguments field" do
        Rake::Task["test:arguments"].invoke(1, 2, 3)
        expect(event_data.count).to be 1
        aggregate_failures do
          event = event_data.first
          expect(event).to include(
            "name" => "rake.test:arguments",
            "rake.arguments" => "[a,b,c]",
          )
          expect(event).not_to include("rake.description")
        end
      end

      it "gives the task access to the Honeycomb client" do
        Rake::Task["test:client:access"].invoke
        names = event_data.map { |event| event["name"] }
        expect(names).to eq ["inner task span", "rake.test:client:access"]
      end

      it "can be disabled on the application level" do
        Rake.application.honeycomb_client = nil
        Rake::Task["test:client:disabled"].invoke
        names = event_data.map { |event| event["name"] }
        expect(names).to eq ["global honeycomb client is still enabled"]
      end

      it "can be disabled on the task level" do
        Rake::Task["test:client:disabled"].honeycomb_client = nil
        Rake::Task["test:client:disabled"].invoke
        names = event_data.map { |event| event["name"] }
        expect(names).to eq ["rake.test:client:enabled", "global honeycomb client is still enabled"]
      end

      it "can use a custom Honeycomb client on the application level" do
        Rake.application.honeycomb_client = custom
        Rake::Task["test:client:custom"].invoke
        aggregate_failures do
          custom_names = custom.libhoney.events.map { |event| event.data["name"] }
          expect(custom_names).to eq ["rake.test:client:default", "rake.test:client:custom"]
          global_names = client.libhoney.events.map { |event| event.data["name"] }
          expect(global_names).to eq ["global honeycomb client"]
        end
      end

      it "can use a custom Honeycomb client on the task level" do
        Rake::Task["test:client:custom"].honeycomb_client = custom
        Rake::Task["test:client:custom"].invoke
        aggregate_failures do
          custom_names = custom.libhoney.events.map { |event| event.data["name"] }
          expect(custom_names).to eq ["rake.test:client:custom"]
          global_names = client.libhoney.events.map { |event| event.data["name"] }
          expect(global_names).to eq ["global honeycomb client", "rake.test:client:default"]
        end
      end
    end
  end
end
