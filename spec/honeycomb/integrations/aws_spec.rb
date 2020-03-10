# frozen_string_literal: true

if defined?(Honeycomb::Aws)
  require "aws-sdk"

  RSpec.describe Honeycomb::Aws do
    before(:context) { Aws.config.update(stub_responses: true) }

    let(:libhoney_client) { Libhoney::TestClient.new }
    let(:event_data) { libhoney_client.events.map(&:data) }
    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.service_name = "example"
        config.client = libhoney_client
      end
    end
    let(:client) { Honeycomb::Client.new(configuration: configuration) }

    def gem_for(service)
      if Honeycomb::Aws::SDK_VERSION.start_with?("2.")
        "aws-sdk"
      else
        "aws-sdk-#{service.const_get(:Client).identifier}"
      end
    end

    def version_of(service)
      if Honeycomb::Aws::SDK_VERSION.start_with?("2.")
        Honeycomb::Aws::SDK_VERSION
      else
        service.const_get(:GEM_VERSION)
      end
    end

    describe "plugin" do
      before do
        Honeycomb.configure do |config|
          config.client = libhoney_client
        end
      end

      let(:aws_clients) do
        Aws::Partitions.service_ids.keys.map do |service|
          Aws.const_get(service).const_get(:Client)
        end
      end

      it "gets added to every aws-sdk client class" do
        expect(aws_clients).to all(satisfy do |aws|
          aws.plugins.include?(Honeycomb::Aws::Plugin)
        end)
      end

      it "is enabled by default" do
        aws = aws_clients.sample.new(endpoint: "https://honeycomb.io")
        expect(aws.handlers).to include(
          Honeycomb::Aws::SdkHandler,
          Honeycomb::Aws::ApiHandler,
        )
      end

      it "can be disabled" do
        aws = aws_clients.sample.new(endpoint: "https://honeycomb.io",
                                     honeycomb: false)
        expect(aws.handlers).not_to include(
          Honeycomb::Aws::SdkHandler,
          Honeycomb::Aws::ApiHandler,
        )
      end

      it "uses the global Honeycomb client by default" do
        aws = aws_clients.sample.new(endpoint: "https://honeycomb.io")
        expect(aws.config.honeycomb_client).to be Honeycomb.client
      end

      it "can be configured with a different Honeycomb client" do
        aws = aws_clients.sample.new(endpoint: "https://honeycomb.io",
                                     honeycomb_client: client)
        expect(aws.config.honeycomb_client).to be client
      end
    end

    describe "basic request" do
      before do
        s3 = Aws::S3::Client.new(honeycomb_client: client)
        s3.list_objects(bucket: "basic")
      end

      it "sends two events" do
        expect(libhoney_client.events.size).to eq 2
      end

      let(:sdk) { event_data.last }

      let(:api) { event_data.first }

      it "sends the expected aws-sdk span" do
        expect(sdk).to match(
          "name" => "aws-sdk",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => an_instance_of(String),
          "meta.span_type" => "root",
          "meta.package" => gem_for(Aws::S3),
          "meta.package_version" => version_of(Aws::S3),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => an_instance_of(String),
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => a_value >= api["duration_ms"],
          "aws.region" => "us-stubbed-1",
          "aws.service" => :s3,
          "aws.operation" => :list_objects,
          "aws.params.bucket" => "basic",
          "aws.request_id" => "stubbed-request-id",
          "aws.retries" => 0,
          "aws.retry_limit" => 3,
        )
      end

      it "sends the expected aws-api span" do
        expect(api).to match(
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::S3),
          "meta.package_version" => version_of(Aws::S3),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :s3,
          "aws.operation" => :list_objects,
          "aws.params.bucket" => "basic",
          "aws.attempt" => 1,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "GET",
          "request.scheme" => "https",
          "request.host" => "basic.s3.us-stubbed-1.amazonaws.com",
          "request.path" => "/",
          "request.query" => "encoding-type=url",
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.status_code" => 200,
          "response.x_amzn_requestid" => "stubbed-request-id",
        )
      end
    end

    describe "client error" do
      before do
        dynamodb = Aws::DynamoDB::Client.new(honeycomb_client: client)

        # Aws::ClientStubs doesn't construct an http body on exceptions
        # Have to do it by hand
        dynamodb.stub_responses(
          :describe_table,
          status_code: 400,
          headers: { "Content-Length" => 138 },
          body: {
            "__type" => "com.amazonaws.dynamodb.v20120810#" \
                        "ResourceNotFoundException",
            "message" => "Requested resource not found: " \
                         "Table: example not found",
          }.to_json,
        )

        expect do
          dynamodb.describe_table(table_name: "example")
        end.to raise_error(Aws::DynamoDB::Errors::ResourceNotFoundException)
      end

      it "sends two events" do
        expect(libhoney_client.events.size).to eq 2
      end

      let(:sdk) { event_data.last }

      let(:api) { event_data.first }

      it "sends the expected aws-sdk span" do
        expect(sdk).to match(
          "name" => "aws-sdk",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => an_instance_of(String),
          "meta.span_type" => "root",
          "meta.package" => gem_for(Aws::DynamoDB),
          "meta.package_version" => version_of(Aws::DynamoDB),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => an_instance_of(String),
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => a_value >= api["duration_ms"],
          "aws.region" => "us-stubbed-1",
          "aws.service" => :dynamodb,
          "aws.operation" => :describe_table,
          "aws.params.table_name" => "example",
          "aws.request_id" => nil,
          "aws.retries" => 0,
          "aws.retry_limit" => 10,
          "aws.error" => "Aws::DynamoDB::Errors::ResourceNotFoundException",
          "aws.error_detail" => "Requested resource not found: " \
                                "Table: example not found",
        )
      end

      it "sends the expected aws-api span" do
        expect(api).to match(
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::DynamoDB),
          "meta.package_version" => version_of(Aws::DynamoDB),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :dynamodb,
          "aws.operation" => :describe_table,
          "aws.params.table_name" => "example",
          "aws.attempt" => 1,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "POST",
          "request.scheme" => "https",
          "request.host" => "dynamodb.us-stubbed-1.amazonaws.com",
          "request.path" => "",
          "request.query" => nil,
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.status_code" => 400,
          "response.error" => "ResourceNotFoundException",
          "response.error_detail" => "Requested resource not found: " \
                                     "Table: example not found",
        )
      end
    end

    describe "networking error" do
      before do
        sqs = Aws::SQS::Client.new(
          access_key_id: "stubbed-akid",
          secret_access_key: "stubbed-secret",
          region: "us-stubbed-1",
          stub_responses: false,
          retry_limit: 0,
          honeycomb_client: client,
        )

        # Logically, we want to stub HTTP to test "real" network error handling
        url = "https://sqs.us-stubbed-1.amazonaws.com/"
        stub_request(:post, url).to_raise(Errno::ETIMEDOUT.new)

        expect do
          sqs.list_queues
        end.to raise_error(Seahorse::Client::NetworkingError)
      end

      it "sends two events" do
        expect(libhoney_client.events.size).to eq 2
      end

      let(:sdk) { event_data.last }

      let(:api) { event_data.first }

      it "sends the expected aws-sdk span" do
        expect(sdk).to match(
          "name" => "aws-sdk",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => an_instance_of(String),
          "meta.span_type" => "root",
          "meta.package" => gem_for(Aws::SQS),
          "meta.package_version" => version_of(Aws::SQS),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => an_instance_of(String),
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => a_value >= api["duration_ms"],
          "aws.region" => "us-stubbed-1",
          "aws.service" => :sqs,
          "aws.operation" => :list_queues,
          "aws.request_id" => nil,
          "aws.retries" => 0,
          "aws.retry_limit" => 0,
          "aws.error" => "Seahorse::Client::NetworkingError",
          "aws.error_detail" => an_instance_of(String),
        )
      end

      it "sends the expected aws-api span" do
        expect(api).to match(
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::SQS),
          "meta.package_version" => version_of(Aws::SQS),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :sqs,
          "aws.operation" => :list_queues,
          "aws.attempt" => 1,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "POST",
          "request.scheme" => "https",
          "request.host" => "sqs.us-stubbed-1.amazonaws.com",
          "request.path" => "",
          "request.query" => nil,
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.error" => "Seahorse::Client::NetworkingError",
          "response.error_detail" => sdk["aws.error_detail"],
        )
      end
    end

    describe "retrying" do
      before do
        kinesis = Aws::Kinesis::Client.new(
          access_key_id: "stubbed-akid",
          secret_access_key: "stubbed-secret",
          region: "us-stubbed-1",
          stub_responses: false,
          honeycomb_client: client,
        )

        # Aws::Plugins::StubResponses disables retries, have to stub http
        url = "https://kinesis.us-stubbed-1.amazonaws.com/"
        http500 = { status: 500 }
        http200 = { status: 200 }
        stub_request(:post, url).to_return(http500, http200)

        kinesis.put_record(stream_name: "a", data: "b", partition_key: "c")
      end

      it "sends three events" do
        expect(libhoney_client.events.size).to eq 3
      end

      let(:api_failure) { event_data[0] }
      let(:api_success) { event_data[1] }
      let(:sdk) { event_data[2] }

      it "sends the expected aws-sdk span" do
        expect(sdk).to match(
          "name" => "aws-sdk",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => an_instance_of(String),
          "meta.span_type" => "root",
          "meta.package" => gem_for(Aws::Kinesis),
          "meta.package_version" => version_of(Aws::Kinesis),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => an_instance_of(String),
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => a_value >= (
            api_success["duration_ms"] + api_failure["duration_ms"]
          ),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :kinesis,
          "aws.operation" => :put_record,
          "aws.params.stream_name" => "a",
          "aws.params.data" => "b",
          "aws.params.partition_key" => "c",
          "aws.request_id" => nil,
          "aws.retries" => 1,
          "aws.retry_limit" => 3,
        )
      end

      it "sends an aws-api span for the original request" do
        expect(api_failure).to match(
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::Kinesis),
          "meta.package_version" => version_of(Aws::Kinesis),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :kinesis,
          "aws.operation" => :put_record,
          "aws.params.stream_name" => "a",
          "aws.params.data" => "b",
          "aws.params.partition_key" => "c",
          "aws.attempt" => 1,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "POST",
          "request.scheme" => "https",
          "request.host" => "kinesis.us-stubbed-1.amazonaws.com",
          "request.path" => "",
          "request.query" => nil,
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.status_code" => 500,
          "response.error" => "Http500Error",
          "response.error_detail" => "",
        )
      end

      it "sends an aws-api span for the retried request" do
        expect(api_success).to match(
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::Kinesis),
          "meta.package_version" => version_of(Aws::Kinesis),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :kinesis,
          "aws.operation" => :put_record,
          "aws.params.stream_name" => "a",
          "aws.params.data" => "b",
          "aws.params.partition_key" => "c",
          "aws.attempt" => 2,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "POST",
          "request.scheme" => "https",
          "request.host" => "kinesis.us-stubbed-1.amazonaws.com",
          "request.path" => "",
          "request.query" => nil,
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.status_code" => 200,
        )
      end
    end

    describe "retry limit exceeded" do
      before do
        ec2 = Aws::EC2::Client.new(
          access_key_id: "stubbed-akid",
          secret_access_key: "stubbed-secret",
          region: "us-stubbed-1",
          stub_responses: false,
          honeycomb_client: client,
        )

        # Aws::Plugins::StubResponses disables retries, have to stub http
        url = "https://ec2.us-stubbed-1.amazonaws.com/"
        http500 = {
          status: 500,
          headers: {},
          body: <<-XML,
            <Response>
              <Errors>
                <Error>
                  <Code>Unavailable</Code>
                  <Message>The server is overloaded.</Message>
                </Error>
              </Errors>
            </Response>
          XML
        }
        stub_request(:post, url).to_return(http500, http500, http500, http500)

        expect do
          ec2.describe_instances
        end.to raise_error(Aws::EC2::Errors::Unavailable)
      end

      it "sends one sdk event plus one event for each api call" do
        expect(libhoney_client.events.size).to eq 5
      end

      let(:sdk) { event_data.last }
      let(:apis) { event_data.take(4) }

      it "sends the expected aws-sdk span" do
        expect(sdk).to match(
          "name" => "aws-sdk",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => an_instance_of(String),
          "meta.span_type" => "root",
          "meta.package" => gem_for(Aws::EC2),
          "meta.package_version" => version_of(Aws::EC2),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => an_instance_of(String),
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => a_value >= apis.map do |api|
            api["duration_ms"]
          end.reduce(&:+),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :ec2,
          "aws.operation" => :describe_instances,
          "aws.request_id" => nil,
          "aws.retries" => 3,
          "aws.retry_limit" => 3,
          "aws.error" => "Aws::EC2::Errors::Unavailable",
          "aws.error_detail" => "The server is overloaded.",
        )
      end

      let(:api) do
        {
          "name" => "aws-api",
          "service_name" => "example",
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.local_hostname" => sdk["meta.local_hostname"],
          "meta.span_type" => "leaf",
          "meta.package" => gem_for(Aws::EC2),
          "meta.package_version" => version_of(Aws::EC2),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "trace.trace_id" => sdk["trace.trace_id"],
          "trace.parent_id" => sdk["trace.span_id"],
          "trace.span_id" => an_instance_of(String),
          "duration_ms" => an_instance_of(Float),
          "aws.region" => "us-stubbed-1",
          "aws.service" => :ec2,
          "aws.operation" => :describe_instances,
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => nil,
          "request.method" => "POST",
          "request.scheme" => "https",
          "request.host" => "ec2.us-stubbed-1.amazonaws.com",
          "request.path" => "",
          "request.query" => nil,
          "request.user_agent" => a_string_starting_with("aws-sdk-ruby"),
          "response.status_code" => 500,
          "response.error" => "Unavailable",
          "response.error_detail" => "The server is overloaded.",
        }
      end

      it "sends the expected aws-api span for each request" do
        expect(apis[0]).to match(api.merge("aws.attempt" => 1))
        expect(apis[1]).to match(api.merge("aws.attempt" => 2))
        expect(apis[2]).to match(api.merge("aws.attempt" => 3))
        expect(apis[3]).to match(api.merge("aws.attempt" => 4))
      end
    end

    describe "s3 region redirect" do
      before do
        # Aws::S3 caches redirected regions, have to reset between tests
        Aws::S3::BUCKET_REGIONS.clear

        s3 = Aws::S3::Client.new(honeycomb_client: client)

        s3.stub_responses(
          :list_objects,
          [
            { status_code: 400, headers: headers, body: body },
            { contents: [] },
          ],
        )

        # disable warnings (aws-sdk dumps them out regardless of logger config)
        verbose = $VERBOSE
        $VERBOSE = nil

        s3.list_objects(bucket: "redirect")

        # re-enable warnings
        $VERBOSE = verbose
      end

      shared_examples "region handling" do
        it "still creates separate aws-api spans" do
          expect(libhoney_client.events.size).to eq 3
        end

        let(:api_failure) { event_data[0] }
        let(:api_success) { event_data[1] }
        let(:sdk) { event_data[2] }

        it "doesn't count as a retry" do
          expect(sdk).to include(
            "aws.region" => "us-stubbed-1",
            "aws.retries" => 0,
          )
        end

        it "uses the supplied region in the original aws-api span" do
          expect(api_failure).to include(
            "aws.region" => "us-stubbed-1",
            "aws.attempt" => 1,
            "request.host" => "redirect.s3.us-stubbed-1.amazonaws.com",
            "response.status_code" => 400,
          )
        end

        it "updates the region in the redirect aws-api span" do
          expect(api_success).to include(
            "aws.region" => "us-stubbed-2",
            "aws.attempt" => 1,
            "request.host" => "redirect.s3.us-stubbed-2.amazonaws.com",
            "response.status_code" => 200,
          )
        end
      end

      context "given by the response headers" do
        let(:headers) { { "x-amz-bucket-region" => "us-stubbed-2" } }
        let(:body) { "whatever" }
        it_behaves_like "region handling"
      end

      context "given by the response body" do
        let(:headers) { {} }
        let(:body) { "<Region>us-stubbed-2</Region>" }
        it_behaves_like "region handling"
      end
    end

    describe "s3 location redirect" do
      before do
        s3 = Aws::S3::Client.new(honeycomb_client: client)
        s3.stub_responses(
          :list_objects,
          [
            {
              status_code: 307,
              headers: {
                "location" => "http://bar.s3.us-stubbed-1.amazonaws.com",
              },
              body: "",
            },
            { contents: [] },
          ],
        )
        s3.list_objects(bucket: "foo")
      end

      it "still creates separate aws-api spans" do
        expect(libhoney_client.events.size).to eq 3
      end

      let(:api_failure) { event_data[0] }
      let(:api_success) { event_data[1] }
      let(:sdk) { event_data[2] }

      it "doesn't count as a retry" do
        expect(sdk).to include("aws.retries" => 0)
      end

      it "uses the old location in the original aws-api span" do
        expect(api_failure).to include(
          "aws.attempt" => 1,
          "request.host" => "foo.s3.us-stubbed-1.amazonaws.com",
          "response.status_code" => 307,
        )
      end

      it "uses the new location in the redirect aws-api span" do
        expect(api_success).to include(
          "aws.attempt" => 1,
          "request.host" => "bar.s3.us-stubbed-1.amazonaws.com",
          "response.status_code" => 200,
        )
      end
    end

    describe "session token" do
      before do
        creds = Aws::Credentials.new(
          "stubbed-akid",
          "stubbed-secret",
          "stubbed-session-token",
        )
        s3 = Aws::S3::Client.new(credentials: creds, honeycomb_client: client)
        s3.list_objects(bucket: "basic")
      end

      it "gets added to the aws-api span" do
        expect(event_data.first).to include(
          "aws.access_key_id" => "stubbed-akid",
          "aws.session_token" => "stubbed-session-token",
        )
      end
    end

    describe "raise_response_errors disabled" do
      before do
        s3 = Aws::S3::Client.new(
          raise_response_errors: false,
          honeycomb_client: client,
        )
        s3.stub_responses(:list_buckets, "AccessDenied")
        s3.list_buckets
      end

      let(:sdk) { event_data.last }
      let(:api) { event_data.first }

      it "still adds error info on the aws-sdk span" do
        expect(sdk).to include(
          "aws.error" => "Aws::S3::Errors::AccessDenied",
          "aws.error_detail" => "stubbed-response-error-message",
        )
      end

      it "still adds error info on the aws-api span" do
        expect(api).to include(
          "response.error" => "AccessDenied",
          "response.error_detail" => "stubbed-response-error-message",
        )
      end
    end

    describe "bad json error payload" do
      before do
        dynamodb = Aws::DynamoDB::Client.new(honeycomb_client: client)
        dynamodb.stub_responses(
          :list_tables,
          status_code: 500,
          headers: {},
          body: "{",
        )
        expect do
          dynamodb.list_tables
        end.to raise_error(Aws::DynamoDB::Errors::Http500Error)
      end

      it "still results in error fields" do
        api, sdk = event_data
        expect(sdk).to include(
          "aws.error" => "Aws::DynamoDB::Errors::Http500Error",
          "aws.error_detail" => "",
        )
        expect(api).to include(
          "response.error" => "Http500Error",
          "response.error_detail" => "",
        )
      end
    end

    describe "s3 http 200 error" do
      before do
        s3 = Aws::S3::Client.new(honeycomb_client: client)

        s3.stub_responses(
          :copy_object,
          status_code: 200,
          headers: {},
          body: <<-XML,
            <Response>
              <Errors>
                <Error>
                  <Code>WTF</Code>
                  <Message>Some special error occurred</Message>
                </Error>
              </Errors>
            </Response>
          XML
        )

        expect do
          s3.copy_object(bucket: "foo", copy_source: "bar", key: "baz")
        end.to raise_error(Aws::S3::Errors::WTF)
      end

      let(:sdk) { event_data.last }

      let(:api) { event_data.first }

      it "still adds error information to the aws-sdk span" do
        expect(sdk).to include(
          "aws.error" => "Aws::S3::Errors::WTF",
          "aws.error_detail" => "Some special error occurred",
        )
      end

      it "doesn't add error information to the aws-api span" do
        expect(api).not_to include("response.error", "response.error_detail")
      end
    end

    describe "dynamodb crc-32 error" do
      before do
        dynamodb = Aws::DynamoDB::Client.new(honeycomb_client: client)

        dynamodb.stub_responses(
          :get_item,
          status_code: 200,
          headers: { "x-amz-crc32" => 1234 },
          body: "",
        )

        expect do
          dynamodb.get_item(table_name: "foo", key: { id: "bar" })
        end.to raise_error(Aws::DynamoDB::Errors::CRC32CheckFailed)
      end

      let(:sdk) { event_data.last }

      let(:api) { event_data.first }

      it "still adds error information to the aws-sdk span" do
        expect(sdk).to include(
          "aws.error" => "Aws::DynamoDB::Errors::CRC32CheckFailed",
          "aws.error_detail" => "Response failed CRC32 check.",
        )
      end

      it "doesn't add error information to the aws-api span" do
        expect(api).not_to include("response.error", "response.error_detail")
      end
    end
  end
end
