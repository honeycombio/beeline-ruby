# frozen_string_literal: true

BASE_FIELDS = %w[
  duration_ms
  meta.beeline_version
  meta.local_hostname
  meta.span_type
  trace.span_id
  trace.trace_id
].freeze

PACKAGE_FIELDS = %w[
  meta.package
  meta.package_version
].freeze

HTTP_FIELDS = %w[
  response.status_code
  request.method
  request.path
  request.query_string
  request.host
  request.remote_addr
  request.header.user_agent
  request.protocol
].freeze

RSpec.shared_examples "event data" do |package_fields: true, http_fields: false|
  describe "data" do
    BASE_FIELDS.each do |field|
      it "includes #{field}" do
        expect(event_data).to all(include field)
      end
    end

    if package_fields
      PACKAGE_FIELDS.each do |field|
        it "includes #{field}" do
          expect(event_data).to all(include field)
        end
      end
    end

    if http_fields
      HTTP_FIELDS.each do |field|
        it "includes #{field}" do
          expect(event_data).to all(include field)
        end
      end
    end
  end
end
