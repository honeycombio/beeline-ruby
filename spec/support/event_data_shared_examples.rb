# frozen_string_literal: true

BASE_FIELDS = %w[
  duration_ms
  meta.beeline_version
  meta.local_hostname
  meta.span_type
  meta.instrumentations
  meta.instrumentations_count
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
  request.header.accept
  request.header.accept_encoding
  request.header.accept_language
  request.header.content_type
  request.header.referer
  request.header.user_agent
  request.header.x_forwarded_for
  request.header.x_forwarded_proto
  request.header.x_forwarded_port
  request.secure
  request.xhr
  request.scheme
].freeze

RSpec.shared_examples "event data" do |package_fields: true, http_fields: false, additional_fields: []|
  describe "data" do
    it "is present" do
      # .all? on an Enumerable like event_data will return true when the collection is empty.
      # Confirm here that there are events to test.
      expect(event_data).not_to be_empty
    end

    BASE_FIELDS.each do |field|
      it "includes #{field}" do
        expect(event_data).to all(include field)
      end
    end

    if package_fields
      PACKAGE_FIELDS.each do |field|
        it "includes #{field}" do
          # the package fields will only be on the root span which should be
          # the last event to be sent in each test
          event = event_data.last
          expect(event).to include field
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

    additional_fields.each do |field|
      it "includes #{field}" do
        expect(event_data).to all(include field)
      end
    end
  end
end
