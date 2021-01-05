require "faraday"
require "sinatra"
require "honeycomb-beeline"
require "honeycomb/propagation/w3c"

Honeycomb.configure do |config|
  config.write_key = "write_key"
  config.dataset = "dataset"
  config.service_name = "service_name"
  config.client = Libhoney::LogClient.new
  config.http_trace_parser_hook do |env|
    # env is a rack env
    case env["REQUEST_PATH"]
    when "/propagation/honeycomb"
      Honeycomb::HoneycombPropagation::UnmarshalTraceContext.parse_rack_env env
    when "/propagation/w3c"
      Honeycomb::W3CPropagation::UnmarshalTraceContext.parse_rack_env env
    else
      # don't start a trace for requests to other paths
    end
  end
  config.http_trace_propagation_hook do |env, context|
    # env is a faraday env and the context is a propagation context
    case env.url.path
    when "/propagation/w3c"
      Honeycomb::W3CPropagation::MarshalTraceContext.parse_faraday_env env, context
    when "/propagation/honeycomb"
      Honeycomb::HoneycombPropagation::MarshalTraceContext.parse_faraday_env env, context
    else
      # do not propagate any trace headers
    end
  end
end

fork do
  use Honeycomb::Sinatra::Middleware, client: Honeycomb.client
  set :port, 4567
  get "/propagation/honeycomb" do
    Honeycomb.start_span(name: "honeycomb_trace") do
      Faraday.get "http://localhost:4568/propagation/w3c"
    end

    "OK"
  end
end

fork do
  use Honeycomb::Sinatra::Middleware, client: Honeycomb.client
  set :port, 4568
  get "/propagation/w3c" do
    Honeycomb.start_span(name: "w3c_trace") do
      Faraday.get "http://localhost:4569/propagation/none"
    end

    "OK"
  end
end

fork do
  use Honeycomb::Sinatra::Middleware, client: Honeycomb.client
  set :port, 4569
  get "/propagation/none" do
    "OK"
  end
end

at_exit do
  Process.wait
end

sleep 3
Faraday.get "http://localhost:4567/propagation/honeycomb"
