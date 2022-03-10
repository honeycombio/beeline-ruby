# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb::Client do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:presend_hook) { proc {} }
  let(:sample_hook) { proc {} }
  let(:parser_hook) { proc {} }
  let(:propagation_hook) { proc {} }
  let(:configuration) do
    Honeycomb::Configuration.new.tap do |config|
      config.client = libhoney_client
      config.presend_hook(&presend_hook)
      config.sample_hook(&sample_hook)
      config.http_trace_parser_hook(&parser_hook)
      config.http_trace_propagation_hook(&propagation_hook)
    end
  end
  subject(:client) { Honeycomb::Client.new(configuration: configuration) }

  it "passes the hooks to the trace on creation" do
    expect(Honeycomb::Trace)
      .to receive(:new)
      .with(hash_including(
              presend_hook: presend_hook,
              sample_hook: sample_hook,
              parser_hook: parser_hook,
              propagation_hook: propagation_hook,
            ))
      .and_call_original

    client.start_span(name: "hi")
  end
end

RSpec.describe Honeycomb::Client do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:configuration) do
    Honeycomb::Configuration.new.tap do |config|
      config.client = libhoney_client
    end
  end
  subject(:client) { Honeycomb::Client.new(configuration: configuration) }

  describe "creating a trace" do
    before do
      client.start_span(name: "test") do # |span|
        client.add_field "test", "wow"
        client.start_span(name: "inner-one") do # |inner_span|
          client.add_field("inner count", 1)
        end
        client.start_span(name: "inner-two") do # |inner_span|
          client.add_field("inner count", 1)
        end
      end
      client.start_span(name: "second trace") do
        client.add_field "test", "wow"
      end
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 4
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end

  describe "passing additional fields on start_span" do
    before do
      client.start_span(name: "trace fields", useless_info: 42) do
      end
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data",
                    package_fields: false,
                    additional_fields: [:useless_info]
  end

  describe "can create a trace without using a block" do
    before do
      outer_span = client.start_span(name: "test")
      client.add_field "test", "wow"
      client.start_span(name: "inner-one") do # |inner_span|
        client.add_field("inner count", 1)
      end
      client.start_span(name: "inner-two") do # |inner_span|
        client.add_field("inner count", 1)
      end
      outer_span.send
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 3
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end

  describe "can create a trace and add error details" do
    let(:the_error) do
      error = ArgumentError.new("an argument!")
      error.set_backtrace(%w[line1 line2])
      error
    end

    before do
      expect do
        client.start_span(name: "test error") do
          raise(the_error)
        end
      end.to raise_error(ArgumentError, "an argument!")
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data",
                    package_fields: false,
                    additional_fields: %w[error error_detail]

    context "when error_backtrace_limit is not configured" do
      it_behaves_like "event data",
                      package_fields: false,
                      additional_fields: %w[error error_detail]
    end

    context "when error_backtrace_limit is set to a negative number" do
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.error_backtrace_limit = -1
        end
      end

      it_behaves_like "event data",
                      package_fields: false,
                      additional_fields: %w[error error_detail]
    end

    context "when error_backtrace_limit is set to 0" do
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.error_backtrace_limit = 0
        end
      end

      it_behaves_like "event data",
                      package_fields: false,
                      additional_fields: %w[error error_detail]
    end

    context "when error_backtrace_limit is set to a positive integer" do
      let(:error_backtrace_limit) { 3 }
      let(:configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = libhoney_client
          config.error_backtrace_limit = error_backtrace_limit
        end
      end

      it "includes the backtrace" do
        backtrace = event_data.first["error_backtrace"]

        aggregate_failures do
          expect(backtrace).not_to be nil
          expect(backtrace.split("\n").length).to be <= error_backtrace_limit
        end
      end

      it "includes error_backtrace_limit set to the configured value" do
        data = event_data.first
        expect(data["error_backtrace_limit"]).to eq(error_backtrace_limit)
      end

      it "includes error_backtrace_total_length as the backtrace's original length" do
        data = event_data.first
        expect(data["error_backtrace_total_length"]).to eq(2)
      end

      it_behaves_like(
        "event data",
        package_fields: false,
        additional_fields: %w[
          error
          error_detail
          error_backtrace
          error_backtrace_limit
          error_backtrace_total_length
        ],
      )

      context "and the error's backtrace is longer than the limit" do
        let(:the_error) do
          error = ArgumentError.new("an argument!")
          error.set_backtrace(
            [
              "error line 1 in <main>",
              "error line 2",
              "error line 3",
              "error line 4",
              "error line 5",
            ],
          )
          error
        end

        it "includes no more than the limit lines in the backtrace field" do
          backtrace = event_data.first["error_backtrace"]

          aggregate_failures do
            expect(backtrace).not_to be nil
            expect(backtrace).to eq(
              "error line 1 in <main>\nerror line 2\nerror line 3",
            )
          end
        end

        it "includes error_backtrace_limit set to the configured value" do
          data = event_data.first
          expect(data["error_backtrace_limit"]).to eq(error_backtrace_limit)
        end

        it "includes error_backtrace_total_length as the backtrace's original length" do
          data = event_data.first
          expect(data["error_backtrace_total_length"]).to eq(5)
        end

        it_behaves_like(
          "event data",
          package_fields: false,
          additional_fields: %w[
            error
            error_detail
            error_backtrace
            error_backtrace_limit
            error_backtrace_total_length
          ],
        )
      end
    end
  end

  describe "can add field to trace" do
    before do
      client.start_span(name: "trace fields") do
        client.add_field_to_trace "useless_info", 42
      end
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 1
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data",
                    package_fields: false,
                    additional_fields: ["app.useless_info"]
  end

  describe "send the whole trace when sending the parent" do
    before do
      root_span = client.start_span(name: "root")
      client.start_span(name: "mid")
      client.start_span(name: "leaf")
      root_span.send
    end

    it "sends the right number of events" do
      expect(libhoney_client.events.size).to eq 3
    end

    let(:event_data) { libhoney_client.events.map(&:data) }

    it_behaves_like "event data", package_fields: false
  end

  describe "sending from within a span block" do
    it "does not also send the parent span" do
      client.start_span(name: "root")

      # rubocop:disable Style/SymbolProc
      client.start_span(name: "child") do |child_span|
        child_span.send
      end
      # rubocop:enable Style/SymbolProc

      expect(libhoney_client.events.size).to eq 1
    end

    it "does not raise an error when the span is the root" do
      expect do
        # rubocop:disable Style/SymbolProc
        client.start_span(name: "child") do |child_span|
          child_span.send
        end
        # rubocop:enable Style/SymbolProc
      end.to_not raise_error
    end
  end

  describe "meta.span_type" do
    let(:event_data) { libhoney_client.events.map(&:data) }

    context "when children are sent before parents" do
      before do
        client.start_span(name: "root") do
          client.start_span(name: "mid") do
            client.start_span(name: "leaf") do
              :ok
            end
          end
        end
      end

      it "has the right values" do
        leaf, mid, root = event_data
        aggregate_failures do
          expect(leaf["name"]).to eq("leaf")
          expect(leaf["meta.span_type"]).to eq("leaf")

          expect(mid["name"]).to eq("mid")
          expect(mid["meta.span_type"]).to eq("mid")

          expect(root["name"]).to eq("root")
          expect(root["meta.span_type"]).to eq("root")
        end
      end
    end

    context "when parents are sent before children" do
      before do
        root = client.start_span(name: "root")
        client.start_span(name: "mid")
        client.start_span(name: "leaf")
        root.send
      end

      it "has the right values" do
        leaf, mid, root = event_data
        aggregate_failures do
          expect(leaf["name"]).to eq("leaf")
          expect(leaf["meta.span_type"]).to eq("leaf")

          expect(mid["name"]).to eq("mid")
          expect(mid["meta.span_type"]).to eq("mid")

          expect(root["name"]).to eq("root")
          expect(root["meta.span_type"]).to eq("root")
        end
      end
    end

    context "when continuing a distributed trace" do
      let(:upstream_configuration) do
        Honeycomb::Configuration.new.tap do |config|
          config.client = Libhoney::NullClient.new
        end
      end

      let(:upstream_client) do
        Honeycomb::Client.new(configuration: upstream_configuration)
      end

      before do
        root = upstream_client.start_span(name: "root")
        root.send

        header = root.to_trace_header
        client.start_span(name: "subroot", serialized_trace: header) do
          client.start_span(name: "mid") do
            client.start_span(name: "leaf") do
              :ok
            end
          end
        end
      end

      it "has the right values" do
        leaf, mid, subroot = event_data
        aggregate_failures do
          expect(leaf["name"]).to eq("leaf")
          expect(leaf["meta.span_type"]).to eq("leaf")

          expect(mid["name"]).to eq("mid")
          expect(mid["meta.span_type"]).to eq("mid")

          expect(subroot["name"]).to eq("subroot")
          expect(subroot["meta.span_type"]).to eq("subroot")
        end
      end
    end
  end
end
