# frozen_string_literal: true

require "honeycomb/integrations/warden"

RSpec.describe Honeycomb::Warden do
  # include Rack::Test::Methods
  # let(:libhoney_client) { Libhoney::TestClient.new }
  # let(:event_data) { libhoney_client.events.map(&:data) }
  # let(:lobster) { Rack::Lobster.new }
  # let(:configuration) do
  #   Honeycomb::Configuration.new.tap do |config|
  #     config.client = libhoney_client
  #   end
  # end
  # let(:client) { Honeycomb::Client.new(configuration: configuration) }
  # let(:honeycomb) do
  #   Honeycomb::Rack::Middleware.new(lobster, client: client)
  # end
  # let(:auth) { Authenticate.new(honeycomb) }
  # let(:warden) do
  #   Warden::Manager.new(auth) do |manager|
  #     manager.default_strategies :test
  #   end
  # end
  # let(:session) { Rack::Session::Cookie.new(warden, secret: "honeycomb") }
  # let(:lint) { Rack::Lint.new(session) }
  # let(:app) { lint }

  let(:user) { double("User", :id => 1, :email => "support@honeycomb.io", :name => "bee", :created_at => DateTime.new(2001,2,3,4,5,6))}
  let(:admin) { double("Admin", :id => 2, :email => "postmaster@honeycomb.io", :name => "queen", :created_at => DateTime.new(2001,2,3,4,5,7))}

  before(:each) do
    @test_obj = Object.new
    @test_obj.extend(Honeycomb::Warden)
  end

  describe "no warden in environment" do
    it "adds no fields" do
      expect { |b| @test_obj.extract_user_information({}, &b) }.not_to yield_control
    end
  end

  describe "session has no users" do
    let(:session) { {"some_key" => "some_value"} }
    let(:env) { {"warden" => 'anything', "rack.session" => session} }

    it "adds no fields" do
      expect { |b| @test_obj.extract_user_information(env, &b) }.not_to yield_control
    end
  end

  describe "session has a regular user" do
    let(:session) { {"warden.user.user.key" => user.id} }
    let(:warden) { instance_double("Warden::Proxy") }
    let(:env) { {"warden" => warden, "rack.session" => session} }

    it "yields fields for a regular user" do
      expect(warden).to receive(:user).with(scope: "user", run_callbacks: false).and_return(user)
      expect { |b| @test_obj.extract_user_information(env, &b) }.to(
        yield_successive_args(["user.email", user.email], ["user.name", user.name], ["user.created_at", user.created_at], ["user.id", user.id])
      )
    end
  end

  describe "session has an admin user" do
    let(:admin_session) { {"warden.user.admin_user.key" => admin.id} }
    let(:admin_warden) { double("Warden::Proxy") }
    let(:admin_env) { {"warden" => admin_warden, "rack.session" => admin_session} }

    it "yields fields for admin user" do
      expect(admin_warden).to receive(:user).with(scope: "admin_user", run_callbacks: false).and_return(admin)
      expect { |b| @test_obj.extract_user_information(admin_env, &b) }.to(
        yield_successive_args(["user.email", admin.email], ["user.name", admin.name], ["user.created_at", admin.created_at], ["user.id", admin.id])
      )
    end
  end

  describe "session has both" do
    let(:both_session) { {"warden.user.user.key" => user.id, "warden.user.admin_user.key" => admin.id} }
    let(:both_warden) { double("Warden::Proxy") }
    let(:both_env) { {"warden" => both_warden, "rack.session" => both_session} }

    it "yields fields for admin user" do
      allow(both_warden).to receive(:user).with(scope: "admin_user", run_callbacks: false).and_return(admin)
      expect(both_warden).to receive(:user).with(scope: "user", run_callbacks: false).and_return(user)
      expect { |b| @test_obj.extract_user_information(both_env, &b) }.to(
        yield_successive_args(["user.email", user.email], ["user.name", user.name], ["user.created_at", user.created_at], ["user.id", user.id])
      )
    end
  end

  # describe "trace header request" do
  #   let(:serialized_trace) do
  #     "1;trace_id=wow,parent_id=eep,dataset=test_dataset"
  #   end

  #   before do
  #     header("X-Honeycomb-Trace", serialized_trace)
  #     get "/?honey=bee"
  #   end

  #   it "returns ok" do
  #     expect(last_response).to be_ok
  #   end

  #   it "sends a single event" do
  #     expect(libhoney_client.events.size).to eq 1
  #   end

  #   it_behaves_like "event data", http_fields: true
  # end
end
