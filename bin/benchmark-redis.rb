#!/usr/bin/env ruby
# frozen_string_literal: true

require "benchmark"
require "ulid"
require "connection_pool"
require "redis"

API_KEY = ENV.fetch("HCKEY")
if API_KEY == ""
  puts "Missing API key in ENV[HCKEY]"
  exit 1
end

DATASET = ENV.fetch("HCDATASET")
if DATASET == ""
  puts "Missing dataset name in ENV[DATASET]"
  exit 1
end

NUMBER = 1000

def redistest
  index = 0
  while index < NUMBER
    index += 1

    data = [].tap { |a| rand(50).times { a.append(ULID.generate) } }.join " "
    key = ULID.generate
    redispool = ConnectionPool.new(size: 5) do
      ::Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" })
    end
    redispool.with do |redis|
      redis.set(key, data)
      redis.expire(key, 60)

      redis.get(key)
      redis.del(key)
    end
  end
end

def hcrequied
  require "honeycomb-beeline"
  redistest
end

def hctestclient
  require "honeycomb-beeline"
  Honeycomb.configure do |config|
    config.client = Libhoney::TestClient.new
  end
  redistest
end

def hcprodclient
  require "honeycomb-beeline"
  Honeycomb.configure do |config|
    config.write_key = API_KEY
    config.dataset = DATASET
  end
  redistest
end

Benchmark.bm(20) do |x|
  x.report("plain redis:") { redistest }
  x.report("plain redis2:") { redistest }
  require "honeycomb-beeline"
  x.report("hc required:") { hcrequied }
  x.report("hc test client:") { hctestclient }
  x.report("hc prod client:") { hcprodclient }
end
