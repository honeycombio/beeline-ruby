require "rack"
require "honeycomb-beeline"

Honeycomb.configure do |config|
  config.write_key = "write_key"
  config.dataset = "dataset"
  config.service_name = "service_name"
  config.client = Libhoney::LogClient.new
end

handler = Rack::Handler::WEBrick

class RackApp
  def call(env)
    Honeycomb.start_span(name: "inner span") do
      [200, {"Content-Type" => "text/plain"}, ["Hello from Honeycomb"]]
    end
  end
end

app = Rack::Builder.new do |builder|
  builder.use Honeycomb::Rack::Middleware, client: Honeycomb.client
  builder.run RackApp.new
end

handler.run app
