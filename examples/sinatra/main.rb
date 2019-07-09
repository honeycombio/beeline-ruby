require "sinatra"
require "honeycomb-beeline"

Honeycomb.configure do |config|
  config.write_key = "write_key"
  config.dataset = "dataset"
  config.service_name = "service_name"
  config.client = Libhoney::LogClient.new
end

use Honeycomb::Rack, client: Honeycomb.client

get "/" do
  "Hello from Honeycomb"
end
