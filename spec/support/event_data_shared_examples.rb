# frozen_string_literal: true

RSpec.shared_examples "event data" do
  describe "data" do
    FIELDS = %w[
      duration_ms
      meta.beeline_version
      meta.local_hostname
      meta.package
      meta.package_version
      meta.span_type
      trace.span_id
      trace.trace_id
    ].freeze

    FIELDS.each do |field|
      it "includes #{field}" do
        expect(event_data).to all(include field)
      end
    end
  end
end
