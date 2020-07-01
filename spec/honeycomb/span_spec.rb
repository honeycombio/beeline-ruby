# frozen_string_literal: true

require "libhoney"

RSpec.describe Honeycomb::Span do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  let(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }
  subject(:span) do
    Honeycomb::Span.new(trace: trace, builder: builder, context: context)
  end

  it_behaves_like "a tracing object"

  it "can add hashes" do
    span.add("key" => "value", "more" => "values")
  end

  it "can add trace fields" do
    span.add_trace_field("key", "value")
  end
end

RSpec.describe Honeycomb::Span do
  let(:libhoney_client) { Libhoney::TestClient.new }
  let(:context) { Honeycomb::Context.new }
  let(:builder) { libhoney_client.builder }
  let(:trace) { Honeycomb::Trace.new(builder: builder, context: context) }

  describe "sample_hook and presend_hook behaviour" do
    let(:presend_hook) { nil }
    let(:sample_rate) { 1 }
    let(:sample_hook) do
      lambda do |_fields|
        [sampling_decision, sample_rate]
      end
    end

    subject(:span) do
      Honeycomb::Span.new(trace: trace,
                          builder: builder,
                          context: context,
                          sample_hook: sample_hook,
                          presend_hook: presend_hook)
    end

    describe "when the sampling hook returns false" do
      let(:sampling_decision) { false }

      it "does not send the event" do
        expect { span.send }.not_to(change { libhoney_client.events })
      end
    end

    describe "when a span creates a child span" do
      let(:presend_hook) { double("PresendHook") }
      let(:sample_hook) { double("SampleHook") }

      before do
        allow(presend_hook).to receive(:call)
        # we have to configure the sample_hook here to return the expected value
        # as the presend_hook will not be called if the event is not going to be
        # sent
        allow(sample_hook).to receive(:call).and_return([true, 0])
      end

      it "sets the sample_hook on the child" do
        expect(sample_hook).to receive(:call)
          .with(hash_including("honeycomb" => "bees"))

        child = span.create_child
        child.add_field("honeycomb", "bees")
        child.send
      end

      it "sets the presend_hook on the child" do
        expect(presend_hook).to receive(:call)
          .with(hash_including("honeycomb" => "bees"))

        child = span.create_child
        child.add_field("honeycomb", "bees")
        child.send
      end
    end

    describe "when the sampling hook returns true" do
      let(:presend_hook) { double("PresendHook") }
      let(:sampling_decision) { true }
      let(:sample_rate) { 10 }

      it "sends the event" do
        allow(presend_hook).to receive(:call)
        expect { span.send }.to change { libhoney_client.events.count }.by(1)
      end

      it "calls the presend hook" do
        expect(presend_hook).to receive(:call)
          .with(hash_including("honeycomb" => "bees"))

        span.add_field("honeycomb", "bees")
        span.send
      end

      it "sets the correct sample rate on the event" do
        allow(presend_hook).to receive(:call)
        span.send
        expect(libhoney_client.events)
          .to all(have_attributes(sample_rate: sample_rate))
      end
    end
  end

  describe "sending children and parents" do
    let(:parent) do
      Honeycomb::Span.new(trace: trace,
                          builder: builder,
                          context: context)
    end

    subject(:child) { parent.create_child }

    it "will remove itself from it's parent after being sent" do
      expect(child).not_to receive(:send_by_parent)

      child.send
      parent.send
    end
  end
end
