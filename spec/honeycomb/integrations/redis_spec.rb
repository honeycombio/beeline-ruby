# frozen_string_literal: true

if defined?(Honeycomb::Redis)
  require "redis/distributed"

  RSpec.describe Honeycomb::Redis do
    VERSION = Gem::Version.new(Redis::VERSION)

    let(:libhoney_client) { Libhoney::TestClient.new }

    let(:event_data) { libhoney_client.events.map(&:data) }

    let(:configuration) do
      Honeycomb::Configuration.new.tap do |config|
        config.service_name = "redis_spec"
        config.client = libhoney_client
      end
    end

    let(:client) { Honeycomb::Client.new(configuration: configuration) }

    let(:connection) { double("Mock Redis connection").as_null_object }

    let(:driver) { double("Mock Redis driver", connect: connection) }

    let(:redis) { Redis.new(driver: driver) }

    shared_context "with the integration configured", configured: true do
      before { Redis.honeycomb_client = client }
    end

    describe "configuration" do
      before do
        Honeycomb.configure { |config| config.client = libhoney_client }
      end

      it "adds Redis.honeycomb_client" do
        expect(Redis).to respond_to(:honeycomb_client)
      end

      it "adds Redis.honeycomb_client=" do
        expect(Redis).to respond_to(:honeycomb_client=)
      end

      it "uses the global client by default" do
        expect(Redis.honeycomb_client).to be Honeycomb.client
      end

      it "can be customized" do
        custom = Honeycomb::Client.new(configuration: configuration)

        original = Redis.honeycomb_client
        expect(original).to_not be custom

        expect do
          Redis.honeycomb_client = custom
        end.to change { Redis.honeycomb_client }.from(original).to(custom)

        Redis.honeycomb_client = original
      end
    end

    shared_examples "the redis span" do |redis_command|
      it "can be disabled (even if Honeycomb is globally configured)" do
        Honeycomb.configure { |config| config.client = libhoney_client }
        Redis.honeycomb_client = nil
        command
        expect(libhoney_client.events).to be_empty
      end

      it "sends one event" do
        command
        expect(libhoney_client.events.size).to eq 1
      end

      let(:event) { event_data.last }

      let(:fields) do
        {
          "duration_ms" => an_instance_of(Float),
          "meta.package" => "redis",
          "meta.package_version" => Redis::VERSION,
          "meta.beeline_version" => Honeycomb::Beeline::VERSION,
          "meta.span_type" => "root",
          "meta.local_hostname" => an_instance_of(String),
          "meta.instrumentations" => an_instance_of(String),
          "meta.instrumentations_count" => 10,
          "name" => "redis",
          "redis.command" => redis_command,
          "redis.db" => 0,
          "redis.driver" => driver,
          "redis.host" => "127.0.0.1",
          "redis.id" => "redis://127.0.0.1:6379/0",
          "redis.location" => "127.0.0.1:6379",
          "redis.path" => nil,
          "redis.port" => 6379,
          "redis.scheme" => "redis",
          "redis.timeout" => a_kind_of(Numeric),
          "service_name" => "redis_spec",
          "trace.span_id" => an_instance_of(String),
          "trace.trace_id" => an_instance_of(String),
        }
      end

      if VERSION >= Gem::Version.new("3.0.2")
        before do
          fields.merge!(
            "redis.tcp_keepalive" => 0,
          )
        end
      end

      if VERSION >= Gem::Version.new("3.1.0")
        before do
          fields.merge!(
            "redis.inherit_socket" => false,
            "redis.reconnect_attempts" => 1,
          )
        end
      end

      if VERSION >= Gem::Version.new("3.2.1")
        before do
          fields.merge!(
            "redis.connect_timeout" => a_kind_of(Numeric),
          )
        end
      end

      if VERSION >= Gem::Version.new("3.3.0")
        before do
          fields.merge!(
            "redis.read_timeout" => a_kind_of(Numeric),
            "redis.write_timeout" => a_kind_of(Numeric),
          )
        end
      end

      if VERSION >= Gem::Version.new("4.0.3")
        before do
          fields.merge!(
            "redis.reconnect_delay" => 0.0,
            "redis.reconnect_delay_max" => 0.5,
          )
        end
      end

      it "sends the expected fields on success" do
        command
        expect(event).to include(fields)
      end

      it "sends the expected fields on failure" do
        exn = Class.new(StandardError)
        expect(connection).to receive(:write).and_raise(exn.new("detail"))
        expect { command }.to raise_error(exn)
        error = { "redis.error" => exn.name, "redis.error_detail" => "detail" }
        expect(event).to include(fields.merge(error))
      end
    end

    describe "commands", configured: true do
      describe "auth" do
        let(:command) { redis.auth("password") }
        it_behaves_like "the redis span", "AUTH [sanitized]" do
          it "respects the command map" do
            if VERSION >= Gem::Version.new("4.0.0")
              redis._client.command_map[:blah] = "auth"
            else
              redis.client.command_map[:blah] = "auth"
            end
            redis.blah("password")
            expect(event).to include(fields)
          end
        end
      end

      describe "select" do
        let(:command) { redis.select(0) }
        it_behaves_like "the redis span", "SELECT 0"
      end

      describe "ping" do
        let(:command) { redis.ping }
        it_behaves_like "the redis span", "PING"
      end

      describe "echo" do
        let(:command) { redis.echo("hello") }
        it_behaves_like "the redis span", "ECHO hello"
      end

      describe "quit" do
        let(:command) { redis.quit }
        it_behaves_like "the redis span", "QUIT"
      end

      describe "bgrewriteaof" do
        let(:command) { redis.bgrewriteaof }
        it_behaves_like "the redis span", "BGREWRITEAOF"
      end

      describe "bgsave" do
        let(:command) { redis.bgsave }
        it_behaves_like "the redis span", "BGSAVE"
      end

      describe "config" do
        describe "get" do
          let(:command) { redis.config(:get, "*") }
          it_behaves_like "the redis span", "CONFIG get *"
        end

        describe "set" do
          let(:command) { redis.config(:set, "timeout", 100) }
          it_behaves_like "the redis span", "CONFIG set timeout 100"
        end

        describe "resetstat" do
          let(:command) { redis.config(:resetstat) }
          it_behaves_like "the redis span", "CONFIG resetstat"
        end

        describe "rewrite" do
          let(:command) { redis.config(:rewrite) }
          it_behaves_like "the redis span", "CONFIG rewrite"
        end
      end

      if VERSION >= Gem::Version.new("4.0.0")
        describe "client" do
          describe "id" do
            let(:command) { redis.client(:id) }
            it_behaves_like "the redis span", "CLIENT id"
          end

          describe "kill" do
            let(:command) { redis.client(:kill, :addr, "127.0.0.1:6379") }
            it_behaves_like "the redis span", "CLIENT kill addr 127.0.0.1:6379"
          end

          describe "list" do
            let(:command) { redis.client(:list, :type, "pubsub") }
            it_behaves_like "the redis span", "CLIENT list type pubsub"
          end

          describe "getname" do
            let(:command) { redis.client(:getname) }
            it_behaves_like "the redis span", "CLIENT getname"
          end

          describe "pause" do
            let(:command) { redis.client(:pause, 123) }
            it_behaves_like "the redis span", "CLIENT pause 123"
          end

          describe "reply" do
            let(:command) { redis.client(:reply, :skip) }
            it_behaves_like "the redis span", "CLIENT reply skip"
          end

          describe "setname" do
            let(:command) { redis.client(:setname, "name") }
            it_behaves_like "the redis span", "CLIENT setname name"
          end

          describe "unblock" do
            let(:command) { redis.client(:unblock, "client-id", :error) }
            it_behaves_like "the redis span", "CLIENT unblock client-id error"
          end
        end
      end

      describe "dbsize" do
        let(:command) { redis.dbsize }
        it_behaves_like "the redis span", "DBSIZE"
      end

      describe "debug" do
        describe "object" do
          let(:command) { redis.debug(:object, "key") }
          it_behaves_like "the redis span", "DEBUG object key"
        end

        describe "segfault" do
          let(:command) { redis.debug(:segfault) }
          it_behaves_like "the redis span", "DEBUG segfault"
        end
      end

      describe "flushall" do
        let(:command) { redis.flushall }
        it_behaves_like "the redis span", "FLUSHALL"
      end

      describe "flushdb" do
        let(:command) { redis.flushdb }
        it_behaves_like "the redis span", "FLUSHDB"
      end

      describe "info" do
        describe "default" do
          let(:command) { redis.info }
          it_behaves_like "the redis span", "INFO"
        end

        describe "section" do
          let(:command) { redis.info("commandstats") }
          it_behaves_like "the redis span", "INFO commandstats"
        end
      end

      describe "lastsave" do
        let(:command) { redis.lastsave }
        it_behaves_like "the redis span", "LASTSAVE"
      end

      describe "monitor" do
        let(:command) do
          expect do
            redis.monitor { throw :monitored }
          end.to throw_symbol(:monitored)
        end
        it_behaves_like "the redis span", "MONITOR"
      end

      describe "save" do
        let(:command) { redis.save }
        it_behaves_like "the redis span", "SAVE"
      end

      describe "shutdown" do
        let(:command) { redis.shutdown }
        it_behaves_like "the redis span", "SHUTDOWN"
      end

      describe "slaveof" do
        let(:command) { redis.slaveof("redis.io", 1234) }
        it_behaves_like "the redis span", "SLAVEOF redis.io 1234"
      end

      describe "slowlog" do
        describe "get" do
          let(:command) { redis.slowlog(:get, 2) }
          it_behaves_like "the redis span", "SLOWLOG get 2"
        end

        describe "len" do
          let(:command) { redis.slowlog(:len) }
          it_behaves_like "the redis span", "SLOWLOG len"
        end

        describe "reset" do
          let(:command) { redis.slowlog(:reset) }
          it_behaves_like "the redis span", "SLOWLOG reset"
        end
      end

      describe "sync" do
        let(:command) { redis.sync }
        it_behaves_like "the redis span", "SYNC"
      end

      describe "time" do
        let(:command) { redis.time }
        it_behaves_like "the redis span", "TIME"
      end

      describe "persist" do
        let(:command) { redis.persist("key") }
        it_behaves_like "the redis span", "PERSIST key"
      end

      describe "expire" do
        let(:command) { redis.expire("key", 1234) }
        it_behaves_like "the redis span", "EXPIRE key 1234"
      end

      describe "expireat" do
        let(:command) { redis.expireat("key", 1234) }
        it_behaves_like "the redis span", "EXPIREAT key 1234"
      end

      describe "ttl" do
        let(:command) { redis.ttl("key") }
        it_behaves_like "the redis span", "TTL key"
      end

      describe "pexpire" do
        let(:command) { redis.pexpire("key", 1234) }
        it_behaves_like "the redis span", "PEXPIRE key 1234"
      end

      describe "pexpireat" do
        let(:command) { redis.pexpireat("key", 1234) }
        it_behaves_like "the redis span", "PEXPIREAT key 1234"
      end

      describe "pttl" do
        let(:command) { redis.pttl("key") }
        it_behaves_like "the redis span", "PTTL key"
      end

      if VERSION >= Gem::Version.new("3.0.3")
        describe "dump" do
          let(:command) { redis.dump("key") }
          it_behaves_like "the redis span", "DUMP key"
        end

        describe "restore" do
          let(:command) { redis.restore("key", 123, "val") }
          it_behaves_like "the redis span", "RESTORE key 123 val"
        end
      end

      if VERSION >= Gem::Version.new("3.0.5")
        describe "migrate" do
          let(:command) do
            redis.migrate(
              "key",
              host: "192.168.1.34",
              port: 6379,
              db: 0,
              timeout: 5000,
            )
          end
          it_behaves_like "the redis span",
                          "MIGRATE 192.168.1.34 6379 key 0 5000"
        end
      end

      describe "del" do
        let(:command) { redis.del("a", "b", "c") }
        it_behaves_like "the redis span", "DEL a b c"
      end

      if VERSION >= Gem::Version.new("4.0.2")
        describe "unlink" do
          let(:command) { redis.unlink("a", "b", "c") }
          it_behaves_like "the redis span", "UNLINK a b c"
        end
      end

      describe "exists" do
        let(:command) { redis.exists("key") }
        it_behaves_like "the redis span", "EXISTS key"
      end

      describe "keys" do
        let(:command) { redis.keys }
        it_behaves_like "the redis span", "KEYS *"
      end

      describe "move" do
        let(:command) { redis.move("key", 1) }
        it_behaves_like "the redis span", "MOVE key 1"
      end

      describe "object" do
        describe "refcount" do
          let(:command) { redis.object(:refcount, "key") }
          it_behaves_like "the redis span", "OBJECT refcount key"
        end

        describe "encoding" do
          let(:command) { redis.object(:encoding, "key") }
          it_behaves_like "the redis span", "OBJECT encoding key"
        end

        describe "idletime" do
          let(:command) { redis.object(:idletime, "key") }
          it_behaves_like "the redis span", "OBJECT idletime key"
        end

        describe "freq" do
          let(:command) { redis.object(:freq, "key") }
          it_behaves_like "the redis span", "OBJECT freq key"
        end

        describe "help" do
          let(:command) { redis.object(:help) }
          it_behaves_like "the redis span", "OBJECT help"
        end
      end

      describe "randomkey" do
        let(:command) { redis.randomkey }
        it_behaves_like "the redis span", "RANDOMKEY"
      end

      describe "rename" do
        let(:command) { redis.rename("old", "new") }
        it_behaves_like "the redis span", "RENAME old new"
      end

      describe "renamenx" do
        let(:command) { redis.renamenx("old", "new") }
        it_behaves_like "the redis span", "RENAMENX old new"
      end

      describe "sort" do
        let(:command) do
          redis.sort(
            "mylist",
            store: "sorted",
            limit: [0, 5],
            order: "ALPHA DESC",
            by: "weight_*",
            get: ["object_*->a", "object_*->b"],
          )
        end
        it_behaves_like "the redis span",
                        "SORT mylist BY weight_* LIMIT 0 5 " \
                        "GET object_*->a GET object_*->b " \
                        "ALPHA DESC STORE sorted"
      end

      describe "type" do
        let(:command) { redis.type("key") }
        it_behaves_like "the redis span", "TYPE key"
      end

      describe "decr" do
        let(:command) { redis.decr("key") }
        it_behaves_like "the redis span", "DECR key"
      end

      describe "decrby" do
        let(:command) { redis.decrby("key", 10) }
        it_behaves_like "the redis span", "DECRBY key 10"
      end

      describe "incr" do
        let(:command) { redis.incr("key") }
        it_behaves_like "the redis span", "INCR key"
      end

      describe "incrby" do
        let(:command) { redis.incrby("key", 10) }
        it_behaves_like "the redis span", "INCRBY key 10"
      end

      describe "incrbyfloat" do
        let(:command) do
          allow(connection).to receive(:read).and_return("-1.23")
          redis.incrbyfloat("key", -1.23)
        end
        it_behaves_like "the redis span", "INCRBYFLOAT key -1.23"
      end

      describe "set" do
        let(:command) { redis.set("key", "val") }
        it_behaves_like "the redis span", "SET key val"
      end

      describe "setex" do
        let(:command) { redis.setex("key", 123, "val") }
        it_behaves_like "the redis span", "SETEX key 123 val"
      end

      describe "psetex" do
        let(:command) { redis.psetex("key", 123, "val") }
        it_behaves_like "the redis span", "PSETEX key 123 val"
      end

      describe "setnx" do
        let(:command) { redis.setnx("key", "val") }
        it_behaves_like "the redis span", "SETNX key val"
      end

      describe "mset" do
        let(:command) { redis.mset("x", 1, "y", 2) }
        it_behaves_like "the redis span", "MSET x 1 y 2"
      end

      describe "mapped_mset" do
        let(:command) { redis.mapped_mset("x" => 1, "y" => 2) }
        it_behaves_like "the redis span", "MSET x 1 y 2"
      end

      describe "msetnx" do
        let(:command) { redis.msetnx("x", 1, "y", 2) }
        it_behaves_like "the redis span", "MSETNX x 1 y 2"
      end

      describe "mapped_msetnx" do
        let(:command) { redis.mapped_msetnx("x" => 1, "y" => 2) }
        it_behaves_like "the redis span", "MSETNX x 1 y 2"
      end

      describe "get" do
        let(:command) { redis.get("key") }
        it_behaves_like "the redis span", "GET key"
      end

      describe "mget" do
        let(:command) do
          expect do
            redis.mget("a", "b", "c") { throw :mgot }
          end.to throw_symbol(:mgot)
        end
        it_behaves_like "the redis span", "MGET a b c"
      end

      describe "mapped_mget" do
        let(:command) { redis.mapped_mget("a", "b", "c") }
        it_behaves_like "the redis span", "MGET a b c"
      end

      describe "setrange" do
        let(:command) { redis.setrange("key", 123, "val") }
        it_behaves_like "the redis span", "SETRANGE key 123 val"
      end

      describe "getrange" do
        let(:command) { redis.getrange("key", 123, 456) }
        it_behaves_like "the redis span", "GETRANGE key 123 456"
      end

      describe "setbit" do
        let(:command) { redis.setbit("key", 8, 1) }
        it_behaves_like "the redis span", "SETBIT key 8 1"
      end

      describe "getbit" do
        let(:command) { redis.getbit("key", 8) }
        it_behaves_like "the redis span", "GETBIT key 8"
      end

      describe "append" do
        let(:command) { redis.append("key", "val") }
        it_behaves_like "the redis span", "APPEND key val"
      end

      if VERSION >= Gem::Version.new("3.0.3")
        describe "bitcount" do
          let(:command) { redis.bitcount("key") }
          it_behaves_like "the redis span", "BITCOUNT key 0 -1"
        end

        describe "bitop" do
          let(:command) { redis.bitop(:xor, "key", "a", "b", "c") }
          it_behaves_like "the redis span", "BITOP xor key a b c"
        end
      end

      if VERSION >= Gem::Version.new("3.1.0")
        describe "bitpos" do
          let(:command) { redis.bitpos("key", 1, 2, 3) }
          it_behaves_like "the redis span", "BITPOS key 1 2 3"
        end
      end

      describe "getset" do
        let(:command) { redis.getset("key", "val") }
        it_behaves_like "the redis span", "GETSET key val"
      end

      describe "strlen" do
        let(:command) { redis.strlen("key") }
        it_behaves_like "the redis span", "STRLEN key"
      end

      describe "llen" do
        let(:command) { redis.llen("key") }
        it_behaves_like "the redis span", "LLEN key"
      end

      describe "lpush" do
        let(:command) { redis.lpush("key", "val") }
        it_behaves_like "the redis span", "LPUSH key val"
      end

      describe "lpushx" do
        let(:command) { redis.lpushx("key", "val") }
        it_behaves_like "the redis span", "LPUSHX key val"
      end

      describe "rpush" do
        let(:command) { redis.rpush("key", "val") }
        it_behaves_like "the redis span", "RPUSH key val"
      end

      describe "rpushx" do
        let(:command) { redis.rpushx("key", "val") }
        it_behaves_like "the redis span", "RPUSHX key val"
      end

      describe "lpop" do
        let(:command) { redis.lpop("key") }
        it_behaves_like "the redis span", "LPOP key"
      end

      describe "rpop" do
        let(:command) { redis.rpop("key") }
        it_behaves_like "the redis span", "RPOP key"
      end

      describe "rpoplpush" do
        let(:command) { redis.rpoplpush("src", "dst") }
        it_behaves_like "the redis span", "RPOPLPUSH src dst"
      end

      describe "blpop" do
        let(:command) { redis.blpop("a", "b", "c", 5) }
        it_behaves_like "the redis span", "BLPOP a b c 5"
      end

      describe "brpop" do
        let(:command) { redis.brpop("a", "b", "c") }
        it_behaves_like "the redis span", "BRPOP a b c 0"
      end

      describe "brpoplpush" do
        let(:command) { redis.brpoplpush("src", "dst", 123) }
        it_behaves_like "the redis span", "BRPOPLPUSH src dst 123"
      end

      describe "lindex" do
        let(:command) { redis.lindex("key", 123) }
        it_behaves_like "the redis span", "LINDEX key 123"
      end

      describe "linsert" do
        let(:command) { redis.linsert("key", :before, "x", "val") }
        it_behaves_like "the redis span", "LINSERT key before x val"
      end

      describe "lrange" do
        let(:command) { redis.lrange("key", 0, 10) }
        it_behaves_like "the redis span", "LRANGE key 0 10"
      end

      describe "lrem" do
        let(:command) { redis.lrem("key", -1, "val") }
        it_behaves_like "the redis span", "LREM key -1 val"
      end

      describe "lset" do
        let(:command) { redis.lset("key", 0, "val") }
        it_behaves_like "the redis span", "LSET key 0 val"
      end

      describe "ltrim" do
        let(:command) { redis.ltrim("key", 10, 20) }
        it_behaves_like "the redis span", "LTRIM key 10 20"
      end

      describe "scard" do
        let(:command) { redis.scard("key") }
        it_behaves_like "the redis span", "SCARD key"
      end

      describe "sadd" do
        let(:command) { redis.sadd("key", "member") }
        it_behaves_like "the redis span", "SADD key member"
      end

      describe "srem" do
        let(:command) { redis.srem("key", "member") }
        it_behaves_like "the redis span", "SREM key member"
      end

      describe "spop" do
        let(:command) { redis.spop("key") }
        it_behaves_like "the redis span", "SPOP key"
      end

      describe "srandmember" do
        let(:command) { redis.srandmember("key") }
        it_behaves_like "the redis span", "SRANDMEMBER key"
      end

      describe "smove" do
        let(:command) { redis.smove("src", "dst", "mem") }
        it_behaves_like "the redis span", "SMOVE src dst mem"
      end

      describe "sismember" do
        let(:command) { redis.sismember("key", "member") }
        it_behaves_like "the redis span", "SISMEMBER key member"
      end

      describe "smembers" do
        let(:command) { redis.smembers("key") }
        it_behaves_like "the redis span", "SMEMBERS key"
      end

      describe "sdiff" do
        let(:command) { redis.sdiff("a", "b", "c") }
        it_behaves_like "the redis span", "SDIFF a b c"
      end

      describe "sdiffstore" do
        let(:command) { redis.sdiffstore("dst", "a", "b", "c") }
        it_behaves_like "the redis span", "SDIFFSTORE dst a b c"
      end

      describe "sinter" do
        let(:command) { redis.sinter("a", "b", "c") }
        it_behaves_like "the redis span", "SINTER a b c"
      end

      describe "sinterstore" do
        let(:command) { redis.sinterstore("dst", "a", "b", "c") }
        it_behaves_like "the redis span", "SINTERSTORE dst a b c"
      end

      describe "sunion" do
        let(:command) { redis.sunion("a", "b", "c") }
        it_behaves_like "the redis span", "SUNION a b c"
      end

      describe "sunionstore" do
        let(:command) { redis.sunionstore("dst", "a", "b", "c") }
        it_behaves_like "the redis span", "SUNIONSTORE dst a b c"
      end

      describe "zcard" do
        let(:command) { redis.zcard("zset") }
        it_behaves_like "the redis span", "ZCARD zset"
      end

      describe "zadd" do
        describe "a single pair" do
          let(:command) { redis.zadd("zset", 32.0, "member") }
          it_behaves_like "the redis span", "ZADD zset 32.0 member"
        end

        describe "multiple pairs" do
          let(:command) { redis.zadd("zset", [[32.0, "a"], [64.0, "b"]]) }
          it_behaves_like "the redis span", "ZADD zset 32.0 a 64.0 b"
        end
      end

      describe "zincrby" do
        let(:command) do
          allow(connection).to receive(:read).and_return("32.0")
          redis.zincrby("zset", 32, "member")
        end
        it_behaves_like "the redis span", "ZINCRBY zset 32 member"
      end

      describe "zrem" do
        let(:command) { redis.zrem("zset", "member") }
        it_behaves_like "the redis span", "ZREM zset member"
      end

      if VERSION >= Gem::Version.new("4.1.0")
        describe "zpopmax" do
          let(:command) { redis.zpopmax("zset") }
          it_behaves_like "the redis span", "ZPOPMAX zset"
        end

        describe "zpopmin" do
          let(:command) { redis.zpopmin("zset", 10) }
          it_behaves_like "the redis span", "ZPOPMIN zset 10"
        end

        describe "bzpopmax" do
          let(:command) { redis.bzpopmax("zset", 1) }
          it_behaves_like "the redis span", "BZPOPMAX zset 1"
        end

        describe "bzpopmin" do
          let(:command) { redis.bzpopmin("zset1", "zset2", 1) }
          it_behaves_like "the redis span", "BZPOPMIN zset1 zset2 1"
        end
      end

      describe "zscore" do
        let(:command) do
          allow(connection).to receive(:read).and_return("32.0")
          redis.zscore("zset", "member")
        end
        it_behaves_like "the redis span", "ZSCORE zset member"
      end

      describe "zrange" do
        describe "with scores" do
          let(:command) { redis.zrange("zset", 0, 10, with_scores: true) }
          it_behaves_like "the redis span", "ZRANGE zset 0 10 WITHSCORES"
        end

        describe "without scores" do
          let(:command) { redis.zrange("zset", 0, 10) }
          it_behaves_like "the redis span", "ZRANGE zset 0 10"
        end
      end

      describe "zrevrange" do
        describe "with scores" do
          let(:command) { redis.zrevrange("zset", 0, 10, withscores: true) }
          it_behaves_like "the redis span", "ZREVRANGE zset 0 10 WITHSCORES"
        end

        describe "without scores" do
          let(:command) { redis.zrevrange("zset", 0, 10) }
          it_behaves_like "the redis span", "ZREVRANGE zset 0 10"
        end
      end

      describe "zrank" do
        let(:command) { redis.zrank("zset", "mem") }
        it_behaves_like "the redis span", "ZRANK zset mem"
      end

      describe "zrevrank" do
        let(:command) { redis.zrevrank("zset", "mem") }
        it_behaves_like "the redis span", "ZREVRANK zset mem"
      end

      describe "zremrangebyrank" do
        let(:command) { redis.zremrangebyrank("zset", 10, 20) }
        it_behaves_like "the redis span", "ZREMRANGEBYRANK zset 10 20"
      end

      if VERSION >= Gem::Version.new("4.0.0")
        describe "zlexcount" do
          let(:command) { redis.zlexcount("zset", 10, 20) }
          it_behaves_like "the redis span", "ZLEXCOUNT zset 10 20"
        end
      end

      if VERSION >= Gem::Version.new("3.2.0")
        describe "zrangebylex" do
          let(:command) { redis.zrangebylex("zset", 10, 20) }
          it_behaves_like "the redis span", "ZRANGEBYLEX zset 10 20"
        end
      end

      if VERSION >= Gem::Version.new("3.2.1")
        describe "zrevrangebylex" do
          let(:command) { redis.zrevrangebylex("zset", 10, 20) }
          it_behaves_like "the redis span", "ZREVRANGEBYLEX zset 10 20"
        end
      end

      describe "zrangebyscore" do
        describe "with scores and limit" do
          let(:command) do
            redis.zrangebyscore("z", 1, 2, with_scores: true, limit: [3, 4])
          end
          it_behaves_like "the redis span",
                          "ZRANGEBYSCORE z 1 2 WITHSCORES LIMIT 3 4"
        end

        describe "with scores and no limit" do
          let(:command) do
            redis.zrangebyscore("z", 1, 2, withscores: true)
          end
          it_behaves_like "the redis span",
                          "ZRANGEBYSCORE z 1 2 WITHSCORES"
        end

        describe "with limit and no scores" do
          let(:command) do
            redis.zrangebyscore("z", 1, 2, limit: [3, 4])
          end
          it_behaves_like "the redis span",
                          "ZRANGEBYSCORE z 1 2 LIMIT 3 4"
        end

        describe "with no scores and no limit" do
          let(:command) do
            redis.zrangebyscore("z", 1, 2)
          end
          it_behaves_like "the redis span",
                          "ZRANGEBYSCORE z 1 2"
        end
      end

      describe "zrevrangebyscore" do
        describe "with scores and limit" do
          let(:command) do
            redis.zrevrangebyscore("z", 1, 2, with_scores: true, limit: [3, 4])
          end
          it_behaves_like "the redis span",
                          "ZREVRANGEBYSCORE z 1 2 WITHSCORES LIMIT 3 4"
        end

        describe "with scores and no limit" do
          let(:command) do
            redis.zrevrangebyscore("z", 1, 2, withscores: true)
          end
          it_behaves_like "the redis span",
                          "ZREVRANGEBYSCORE z 1 2 WITHSCORES"
        end

        describe "with limit and no scores" do
          let(:command) do
            redis.zrevrangebyscore("z", 1, 2, limit: [3, 4])
          end
          it_behaves_like "the redis span",
                          "ZREVRANGEBYSCORE z 1 2 LIMIT 3 4"
        end

        describe "with no scores and no limit" do
          let(:command) do
            redis.zrevrangebyscore("z", 1, 2)
          end
          it_behaves_like "the redis span",
                          "ZREVRANGEBYSCORE z 1 2"
        end
      end

      describe "zremrangebyscore" do
        let(:command) { redis.zremrangebyscore("zset", 100, 200) }
        it_behaves_like "the redis span", "ZREMRANGEBYSCORE zset 100 200"
      end

      describe "zcount" do
        let(:command) { redis.zcount("zset", 100, 200) }
        it_behaves_like "the redis span", "ZCOUNT zset 100 200"
      end

      describe "zinterstore" do
        describe "with weights and aggregate" do
          let(:command) do
            redis.zinterstore "c", %w[a b], weights: [2, 1], aggregate: "sum"
          end
          it_behaves_like "the redis span",
                          "ZINTERSTORE c 2 a b WEIGHTS 2 1 AGGREGATE sum"
        end

        describe "with weights and no aggregate" do
          let(:command) do
            redis.zinterstore "c", %w[a b], weights: [2, 1]
          end
          it_behaves_like "the redis span",
                          "ZINTERSTORE c 2 a b WEIGHTS 2 1"
        end

        describe "with aggregate and no weights" do
          let(:command) do
            redis.zinterstore "c", %w[a b], aggregate: "sum"
          end
          it_behaves_like "the redis span",
                          "ZINTERSTORE c 2 a b AGGREGATE sum"
        end

        describe "with no weights and no aggregate" do
          let(:command) do
            redis.zinterstore "c", %w[a b]
          end
          it_behaves_like "the redis span",
                          "ZINTERSTORE c 2 a b"
        end
      end

      describe "zunionstore" do
        describe "with weights and aggregate" do
          let(:command) do
            redis.zunionstore "c", %w[a b], weights: [2, 1], aggregate: "sum"
          end
          it_behaves_like "the redis span",
                          "ZUNIONSTORE c 2 a b WEIGHTS 2 1 AGGREGATE sum"
        end

        describe "with weights and no aggregate" do
          let(:command) do
            redis.zunionstore "c", %w[a b], weights: [2, 1]
          end
          it_behaves_like "the redis span",
                          "ZUNIONSTORE c 2 a b WEIGHTS 2 1"
        end

        describe "with aggregate and no weights" do
          let(:command) do
            redis.zunionstore "c", %w[a b], aggregate: "sum"
          end
          it_behaves_like "the redis span",
                          "ZUNIONSTORE c 2 a b AGGREGATE sum"
        end

        describe "with no weights and no aggregate" do
          let(:command) do
            redis.zunionstore "c", %w[a b]
          end
          it_behaves_like "the redis span",
                          "ZUNIONSTORE c 2 a b"
        end
      end

      describe "hlen" do
        let(:command) { redis.hlen("key") }
        it_behaves_like "the redis span", "HLEN key"
      end

      describe "hset" do
        let(:command) { redis.hset("key", "field", "value") }
        it_behaves_like "the redis span", "HSET key field value"
      end

      describe "hsetnx" do
        let(:command) { redis.hsetnx("key", "field", "value") }
        it_behaves_like "the redis span", "HSETNX key field value"
      end

      describe "hmset" do
        let(:command) { redis.hmset("key", "x", 1, "y", 2) }
        it_behaves_like "the redis span", "HMSET key x 1 y 2"
      end

      describe "mapped_hmset" do
        let(:command) { redis.mapped_hmset("key", "x" => 1, "y" => 2) }
        it_behaves_like "the redis span", "HMSET key x 1 y 2"
      end

      describe "hget" do
        let(:command) { redis.hget("key", "field") }
        it_behaves_like "the redis span", "HGET key field"
      end

      describe "hmget" do
        let(:command) do
          expect do
            redis.hmget("key", "a", "b", "c") { throw :hmgot }
          end.to throw_symbol(:hmgot)
        end
        it_behaves_like "the redis span", "HMGET key a b c"
      end

      describe "mapped_hmget" do
        let(:command) { redis.mapped_hmget("key", "a", "b", "c") }
        it_behaves_like "the redis span", "HMGET key a b c"
      end

      describe "hdel" do
        let(:command) { redis.hdel("key", "field") }
        it_behaves_like "the redis span", "HDEL key field"
      end

      describe "hexists" do
        let(:command) { redis.hexists("key", "field") }
        it_behaves_like "the redis span", "HEXISTS key field"
      end

      describe "hincrby" do
        let(:command) { redis.hincrby("key", "field", 123) }
        it_behaves_like "the redis span", "HINCRBY key field 123"
      end

      describe "hincrbyfloat" do
        let(:command) do
          allow(connection).to receive(:read).and_return("1.23")
          redis.hincrbyfloat("key", "field", 1.23)
        end
        it_behaves_like "the redis span", "HINCRBYFLOAT key field 1.23"
      end

      describe "hkeys" do
        let(:command) { redis.hkeys("key") }
        it_behaves_like "the redis span", "HKEYS key"
      end

      describe "hvals" do
        let(:command) { redis.hvals("key") }
        it_behaves_like "the redis span", "HVALS key"
      end

      describe "hgetall" do
        let(:command) { redis.hgetall("key") }
        it_behaves_like "the redis span", "HGETALL key"
      end

      describe "publish" do
        let(:command) { redis.publish("channel", "message") }
        it_behaves_like "the redis span", "PUBLISH channel message"
      end

      if VERSION >= Gem::Version.new("3.2.1")
        describe "pubsub" do
          describe "channels" do
            let(:command) { redis.pubsub(:channels, "*") }
            it_behaves_like "the redis span", "PUBSUB channels *"
          end

          describe "numsub" do
            let(:command) { redis.pubsub(:numsub, "a", "b", "c") }
            it_behaves_like "the redis span", "PUBSUB numsub a b c"
          end

          describe "numpat" do
            let(:command) { redis.pubsub(:numpat) }
            it_behaves_like "the redis span", "PUBSUB numpat"
          end
        end
      end

      describe "watch" do
        let(:command) { redis.watch("a", "b", "c") }
        it_behaves_like "the redis span", "WATCH a b c"
      end

      describe "unwatch" do
        let(:command) { redis.unwatch }
        it_behaves_like "the redis span", "UNWATCH"
      end

      describe "multi" do
        describe "without a block" do
          let(:command) { redis.multi }
          it_behaves_like "the redis span", "MULTI"
        end

        describe "with a block" do
          let(:command) do
            # Without this, we get `TypeError: exception object expected`
            # https://github.com/redis/redis-rb/blob/c7b69ba012b353f85d1b7a611380617e36bd2f2a/lib/redis/pipeline.rb#L95
            allow(connection).to receive(:read).and_return("OK")

            redis.multi do |multi|
              multi.set("x", 1)
              multi.set("y", 2)
            end
          end
          it_behaves_like "the redis span", "MULTI\nSET x 1\nSET y 2\nEXEC"
        end
      end

      describe "exec" do
        let(:command) { redis.exec }
        it_behaves_like "the redis span", "EXEC"
      end

      describe "discard" do
        let(:command) { redis.discard }
        it_behaves_like "the redis span", "DISCARD"
      end

      describe "script" do
        describe "debug" do
          let(:command) { redis.script(:debug, :yes) }
          it_behaves_like "the redis span", "SCRIPT debug yes"
        end

        describe "exists" do
          let(:command) { redis.script(:exists, "sha") }
          it_behaves_like "the redis span", "SCRIPT exists sha"
        end

        describe "flush" do
          let(:command) { redis.script(:flush) }
          it_behaves_like "the redis span", "SCRIPT flush"
        end

        describe "load" do
          let(:command) { redis.script(:load, "script") }
          it_behaves_like "the redis span", "SCRIPT load script"
        end
      end

      describe "eval" do
        let(:command) { redis.eval("script", keys: %w[a b c], argv: %w[x y z]) }
        it_behaves_like "the redis span", "EVAL script 3 a b c x y z"
      end

      describe "evalsha" do
        let(:command) { redis.evalsha("sha", %w[a b c], %w[x y z]) }
        it_behaves_like "the redis span", "EVALSHA sha 3 a b c x y z"
      end

      if VERSION >= Gem::Version.new("3.0.6")
        describe "scan" do
          let(:command) { redis.scan(0) }
          it_behaves_like "the redis span", "SCAN 0"
        end

        describe "hscan" do
          let(:command) { redis.hscan("key", 1, match: "pattern") }
          it_behaves_like "the redis span", "HSCAN key 1 MATCH pattern"
        end

        describe "zscan" do
          let(:command) { redis.zscan("key", 2, count: 10) }
          it_behaves_like "the redis span", "ZSCAN key 2 COUNT 10"
        end

        describe "sscan" do
          let(:command) { redis.sscan("key", 3, match: "*", count: 10) }
          it_behaves_like "the redis span", "SSCAN key 3 MATCH * COUNT 10"
        end
      end

      if VERSION >= Gem::Version.new("3.1.0")
        describe "pfadd" do
          let(:command) { redis.pfadd("key", "member") }
          it_behaves_like "the redis span", "PFADD key member"
        end

        describe "pfcount" do
          let(:command) { redis.pfcount("key") }
          it_behaves_like "the redis span", "PFCOUNT key"
        end

        describe "pfmerge" do
          let(:command) { redis.pfmerge("dst", "src") }
          it_behaves_like "the redis span", "PFMERGE dst src"
        end
      end

      if VERSION >= Gem::Version.new("4.0.2")
        describe "geoadd" do
          let(:command) do
            redis.geoadd(
              "Sicily",
              13.361389,
              38.115556,
              "Palermo",
              15.087269,
              37.502669,
              "Catania",
            )
          end

          it_behaves_like "the redis span",
                          "GEOADD Sicily " \
                          "13.361389 38.115556 Palermo " \
                          "15.087269 37.502669 Catania"
        end

        describe "geohash" do
          let(:command) do
            redis.geohash("Sicily", %w[Palermo Catania])
          end

          it_behaves_like "the redis span",
                          "GEOHASH Sicily Palermo Catania"
        end

        describe "georadius" do
          let(:command) do
            redis.georadius("Sicily", 15, 37, 200, "km", options: :WITHDIST)
          end

          it_behaves_like "the redis span",
                          "GEORADIUS Sicily 15 37 200 km WITHDIST"
        end

        describe "georadiusbymember" do
          let(:command) do
            redis.georadiusbymember("Sicily", "Agrigento", 100, "km")
          end

          it_behaves_like "the redis span",
                          "GEORADIUSBYMEMBER Sicily Agrigento 100 km"
        end

        describe "geopos" do
          let(:command) do
            redis.geopos("Sicily", %w[Palermo Catania NonExisting])
          end

          it_behaves_like "the redis span",
                          "GEOPOS Sicily Palermo Catania NonExisting"
        end

        describe "geodist" do
          let(:command) do
            redis.geodist("Sicily", "Palermo", "Catania")
          end

          it_behaves_like "the redis span",
                          "GEODIST Sicily Palermo Catania m"
        end
      end

      if VERSION >= Gem::Version.new("4.1.0")
        describe "xinfo" do
          describe "stream" do
            let(:command) { redis.xinfo(:stream, "key") }
            it_behaves_like "the redis span", "XINFO stream key"
          end

          describe "groups" do
            let(:command) { redis.xinfo(:groups, "key") }
            it_behaves_like "the redis span", "XINFO groups key"
          end

          describe "consumers" do
            let(:command) { redis.xinfo(:consumers, "key", "group") }
            it_behaves_like "the redis span", "XINFO consumers key group"
          end
        end

        describe "xadd" do
          let(:command) do
            redis.xadd(
              "key",
              { a: 1, b: 2 },
              id: "0-0",
              maxlen: 100,
              approximate: true,
            )
          end
          it_behaves_like "the redis span", "XADD key MAXLEN ~ 100 0-0 a 1 b 2"
        end

        describe "xtrim" do
          let(:command) { redis.xtrim("key", 1000, approximate: true) }
          it_behaves_like "the redis span", "XTRIM key MAXLEN ~ 1000"
        end

        describe "xdel" do
          let(:command) { redis.xdel("key", "a", "b", "c") }
          it_behaves_like "the redis span", "XDEL key a b c"
        end

        describe "xrange" do
          let(:command) { redis.xrange("key", count: 100) }
          it_behaves_like "the redis span", "XRANGE key - + COUNT 100"
        end

        describe "xrevrange" do
          let(:command) { redis.xrevrange("key", "867-5309") }
          it_behaves_like "the redis span", "XREVRANGE key 867-5309 -"
        end

        describe "xlen" do
          let(:command) { redis.xlen("key") }
          it_behaves_like "the redis span", "XLEN key"
        end

        describe "xread" do
          let(:command) { redis.xread(%w[a b c], %w[0-0 1-1 2-2], count: 10) }
          it_behaves_like "the redis span",
                          "XREAD COUNT 10 STREAMS a b c 0-0 1-1 2-2"
        end

        describe "xgroup" do
          describe "create" do
            let(:command) { redis.xgroup(:create, "stream", "group", "$") }
            it_behaves_like "the redis span", "XGROUP create stream group $"
          end

          describe "setid" do
            let(:command) { redis.xgroup(:setid, "stream", "group", "$") }
            it_behaves_like "the redis span", "XGROUP setid stream group $"
          end

          describe "destroy" do
            let(:command) { redis.xgroup(:destroy, "stream", "group") }
            it_behaves_like "the redis span", "XGROUP destroy stream group"
          end

          describe "delconsumer" do
            let(:command) do
              redis.xgroup(:delconsumer, "stream", "group", "consumer")
            end
            it_behaves_like "the redis span",
                            "XGROUP delconsumer stream group consumer"
          end
        end

        describe "xreadgroup" do
          let(:command) { redis.xreadgroup("g", "c", "k", "0-0", noack: true) }
          it_behaves_like "the redis span",
                          "XREADGROUP GROUP g c NOACK STREAMS k 0-0"
        end

        describe "xack" do
          let(:command) { redis.xack("key", "group", "0-0", "1-1", "2-2") }
          it_behaves_like "the redis span", "XACK key group 0-0 1-1 2-2"
        end

        describe "xclaim" do
          let(:command) do
            redis.xclaim("k", "g", "c", 100, "0-0", retrycount: 10)
          end
          it_behaves_like "the redis span",
                          "XCLAIM k g c 100 0-0 RETRYCOUNT 10"
        end

        describe "xpending" do
          let(:command) { redis.xpending("k", "g", "-", "+", 10, "c") }
          it_behaves_like "the redis span", "XPENDING k g - + 10 c"
        end
      end

      if VERSION >= Gem::Version.new("3.2.2")
        describe "sentinel" do
          let(:command) { redis.sentinel(:masters) }
          it_behaves_like "the redis span", "SENTINEL masters"
        end
      end

      if VERSION >= Gem::Version.new("4.1.0")
        describe "cluster" do
          describe "addslots" do
            let(:command) { redis.cluster(:addslots, 1, 2, 3) }
            it_behaves_like "the redis span",
                            "CLUSTER addslots 1 2 3"
          end

          describe "bumpepoch" do
            let(:command) { redis.cluster(:bumpepoch) }
            it_behaves_like "the redis span",
                            "CLUSTER bumpepoch"
          end

          describe "count-failure-reports" do
            let(:command) { redis.cluster("COUNT-FAILURE-REPORTS", "node-id") }
            it_behaves_like "the redis span",
                            "CLUSTER count-failure-reports node-id"
          end

          describe "countkeysinslot" do
            let(:command) { redis.cluster(:countkeysinslot, 1) }
            it_behaves_like "the redis span",
                            "CLUSTER countkeysinslot 1"
          end

          describe "delslots" do
            let(:command) { redis.cluster(:delslots, 1, 2, 3) }
            it_behaves_like "the redis span",
                            "CLUSTER delslots 1 2 3"
          end

          describe "failover" do
            let(:command) { redis.cluster(:failover, :force) }
            it_behaves_like "the redis span",
                            "CLUSTER failover force"
          end

          describe "flushslots" do
            let(:command) { redis.cluster(:flushslots) }
            it_behaves_like "the redis span",
                            "CLUSTER flushslots"
          end

          describe "forget" do
            let(:command) { redis.cluster(:forget, "node-id") }
            it_behaves_like "the redis span",
                            "CLUSTER forget node-id"
          end

          describe "getkeysinslot" do
            let(:command) { redis.cluster(:getkeysinslot, "1", 3) }
            it_behaves_like "the redis span",
                            "CLUSTER getkeysinslot 1 3"
          end

          describe "info" do
            let(:command) { redis.cluster(:info) }
            it_behaves_like "the redis span",
                            "CLUSTER info"
          end

          describe "keyslot" do
            let(:command) { redis.cluster(:keyslot, "key") }
            it_behaves_like "the redis span",
                            "CLUSTER keyslot key"
          end

          describe "meet" do
            let(:command) { redis.cluster(:meet, "127.0.0.1", 6379) }
            it_behaves_like "the redis span",
                            "CLUSTER meet 127.0.0.1 6379"
          end

          describe "myid" do
            let(:command) { redis.cluster(:myid) }
            it_behaves_like "the redis span",
                            "CLUSTER myid"
          end

          describe "nodes" do
            let(:command) { redis.cluster(:nodes) }
            it_behaves_like "the redis span",
                            "CLUSTER nodes"
          end

          describe "replicate" do
            let(:command) { redis.cluster(:replicate, "node-id") }
            it_behaves_like "the redis span",
                            "CLUSTER replicate node-id"
          end

          describe "reset" do
            let(:command) { redis.cluster(:reset, :soft) }
            it_behaves_like "the redis span",
                            "CLUSTER reset soft"
          end

          describe "saveconfig" do
            let(:command) { redis.cluster(:saveconfig) }
            it_behaves_like "the redis span",
                            "CLUSTER saveconfig"
          end

          describe "set-config-epoch" do
            let(:command) { redis.cluster("set-config-epoch", 0) }
            it_behaves_like "the redis span",
                            "CLUSTER set-config-epoch 0"
          end

          describe "setslot" do
            let(:command) { redis.cluster(:setslot, :importing) }
            it_behaves_like "the redis span",
                            "CLUSTER setslot importing"
          end

          describe "slaves" do
            let(:command) { redis.cluster(:slaves, "node-id") }
            it_behaves_like "the redis span",
                            "CLUSTER slaves node-id"
          end

          describe "replicas" do
            let(:command) { redis.cluster(:replicas, "node-id") }
            it_behaves_like "the redis span",
                            "CLUSTER replicas node-id"
          end

          describe "slots" do
            let(:command) { redis.cluster(:slots) }
            it_behaves_like "the redis span",
                            "CLUSTER slots"
          end
        end

        describe "asking" do
          let(:command) { redis.asking }
          it_behaves_like "the redis span", "ASKING"
        end
      end
    end

    describe "pipelining", configured: true do
      if VERSION >= Gem::Version.new("3.3.0")
        describe "using #queue + #commit" do
          let(:command) do
            redis.queue(:set, "x", 1)
            redis.queue(:set, "y", 2)
            redis.commit
          end
          it_behaves_like "the redis span", "SET x 1\nSET y 2"
        end
      end

      describe "using #pipelined" do
        let(:command) do
          redis.pipelined do
            redis.set("x", 1)
            redis.set("y", 2)
          end
        end
        it_behaves_like "the redis span", "SET x 1\nSET y 2"
      end
    end

    if VERSION >= Gem::Version.new("3.0.6")
      describe "scan enumerators", configured: true do
        describe "#scan_each" do
          before do
            allow(connection).to receive(:read).and_return(
              ["5", %w[a b c]],
              ["0", %w[x y z]],
            )
            expect(redis.scan_each.to_a).to eq %w[a b c x y z]
          end

          it "generates an event for each SCAN" do
            expect(libhoney_client.events.size).to eq 2
            expect(event_data).to all include("meta.span_type" => "root")
            expect(event_data[0]).to include("redis.command" => "SCAN 0")
            expect(event_data[1]).to include("redis.command" => "SCAN 5")
          end
        end

        describe "#hscan_each" do
          before do
            allow(connection).to receive(:read).and_return(
              ["2", %w[a x]],
              ["4", %w[b y]],
              ["0", %w[c z]],
            )
            expect(redis.hscan_each("key").to_a).to eq [
              %w[a x],
              %w[b y],
              %w[c z],
            ]
          end

          it "generates an event for each HSCAN" do
            expect(libhoney_client.events.size).to eq 3
            expect(event_data).to all include("meta.span_type" => "root")
            expect(event_data[0]).to include("redis.command" => "HSCAN key 0")
            expect(event_data[1]).to include("redis.command" => "HSCAN key 2")
            expect(event_data[2]).to include("redis.command" => "HSCAN key 4")
          end
        end

        describe "#zscan_each" do
          before do
            allow(connection).to receive(:read).and_return(
              ["8", %w[a 1 b 2]],
              ["0", %w[c 3]],
            )
            expect(redis.zscan_each("key").to_a).to eq [
              ["a", 1.0],
              ["b", 2.0],
              ["c", 3.0],
            ]
          end

          it "generates an event for each ZSCAN" do
            expect(libhoney_client.events.size).to eq 2
            expect(event_data).to all include("meta.span_type" => "root")
            expect(event_data[0]).to include("redis.command" => "ZSCAN key 0")
            expect(event_data[1]).to include("redis.command" => "ZSCAN key 8")
          end
        end

        describe "#sscan_each" do
          before do
            allow(connection).to receive(:read).and_return(
              ["5", %w[a b c]],
              ["0", %w[x y z]],
            )
            expect(redis.sscan_each("key").to_a).to eq %w[a b c x y z]
          end

          it "generates an event for each SSCAN" do
            expect(libhoney_client.events.size).to eq 2
            expect(event_data).to all include("meta.span_type" => "root")
            expect(event_data[0]).to include("redis.command" => "SSCAN key 0")
            expect(event_data[1]).to include("redis.command" => "SSCAN key 5")
          end
        end
      end
    end

    describe "reconnecting", configured: true do
      before do
        redis.connect
        libhoney_client.events.clear
        expect(connection).to receive(:connected?).and_return(false)
        redis.set("x", 1)
      end

      describe "with authentication" do
        let(:redis) { Redis.new(driver: driver, password: "password") }

        it "sends two events" do
          expect(libhoney_client.events.size).to eq 2
        end

        let(:leaf) { event_data.first }

        let(:root) { event_data.last }

        it "sends the actual command as a parent span" do
          expect(root).to include(
            "meta.span_type" => "root",
            "redis.command" => "SET x 1",
          )
        end

        it "sends the automatic AUTH as a child span" do
          expect(leaf).to include(
            "trace.parent_id" => root["trace.span_id"],
            "redis.command" => "AUTH [sanitized]",
          )
        end
      end

      describe "with a selected db" do
        let(:redis) { Redis.new(driver: driver, db: 10) }

        it "sends two events" do
          expect(libhoney_client.events.size).to eq 2
        end

        let(:leaf) { event_data.first }

        let(:root) { event_data.last }

        it "sends the actual command as a parent span" do
          expect(root).to include(
            "meta.span_type" => "root",
            "redis.command" => "SET x 1",
          )
        end

        it "sends the automatic SELECT as a child span" do
          expect(leaf).to include(
            "trace.parent_id" => root["trace.span_id"],
            "redis.command" => "SELECT 10",
          )
        end
      end

      if VERSION >= Gem::Version.new("3.2.2")
        describe "with a client name" do
          let(:redis) { Redis.new(driver: driver, id: "name") }

          it "sends two events" do
            expect(libhoney_client.events.size).to eq 2
          end

          let(:leaf) { event_data.first }

          let(:root) { event_data.last }

          it "sends the actual command as a parent span" do
            expect(root).to include(
              "meta.span_type" => "root",
              "redis.command" => "SET x 1",
            )
          end

          it "sends the automatic CLIENT SETNAME as a child span" do
            expect(leaf).to include(
              "trace.parent_id" => root["trace.span_id"],
              "redis.command" => "CLIENT setname name",
            )
          end
        end
      end
    end

    describe "pub/sub commands", configured: true do
      describe "subscribe + unsubscribe" do
        before do
          expect(connection).to receive(:read).and_return(
            ["subscribe", "channel", 1],
            %w[message channel hello],
            ["unsubscribe", "channel", 0],
          )

          redis.subscribe("channel") do |on|
            on.message { redis.unsubscribe }
          end

          # https://github.com/redis/redis-rb/issues/305
          if VERSION < Gem::Version.new("3.0.3")
            _redundant_unsubscribe = libhoney_client.events.pop
          end
        end

        it "generates two events" do
          expect(libhoney_client.events.size).to eq 2
        end

        let(:root) { event_data[1] }

        it "sends a subscribe event" do
          expect(root).to include(
            "meta.span_type" => "root",
            "redis.command" => "SUBSCRIBE channel",
          )
        end

        let(:leaf) { event_data[0] }

        it "sends an unsubcribe event" do
          expect(leaf).to include(
            "trace.parent_id" => root["trace.span_id"],
            "redis.command" => "UNSUBSCRIBE",
          )
        end
      end

      describe "psubscribe + punsubscribe" do
        before do
          expect(connection).to receive(:read).and_return(
            ["psubscribe", "channel", 1],
            %w[message channel hello],
            ["punsubscribe", "channel", 0],
          )

          redis.psubscribe("chan*") do |on|
            on.message { redis.punsubscribe("chan*") }
          end

          # https://github.com/redis/redis-rb/issues/305
          if VERSION < Gem::Version.new("3.0.3")
            _redundant_unsubscribe = libhoney_client.events.pop
          end
        end

        it "generates two events" do
          expect(libhoney_client.events.size).to eq 2
        end

        let(:root) { event_data[1] }

        it "sends a psubscribe event" do
          expect(root).to include(
            "meta.span_type" => "root",
            "redis.command" => "PSUBSCRIBE chan*",
          )
        end

        let(:leaf) { event_data[0] }

        it "sends a punsubcribe event" do
          expect(leaf).to include(
            "trace.parent_id" => root["trace.span_id"],
            "redis.command" => "PUNSUBSCRIBE chan*",
          )
        end
      end

      if VERSION >= Gem::Version.new("3.3.0")
        describe "with timeouts" do
          describe "subscribe + unsubscribe" do
            before do
              expect(connection).to receive(:read).and_return(
                ["subscribe", "channel", 1],
                %w[message channel hello],
                ["unsubscribe", "channel", 0],
              )
              redis.subscribe_with_timeout(100, "channel") do |on|
                on.message { redis.unsubscribe }
              end
            end

            it "generates two events" do
              expect(libhoney_client.events.size).to eq 2
            end

            let(:root) { event_data[1] }

            it "sends a subscribe event" do
              expect(root).to include(
                "meta.span_type" => "root",
                "redis.command" => "SUBSCRIBE channel",
              )
            end

            let(:leaf) { event_data[0] }

            it "sends an unsubcribe event" do
              expect(leaf).to include(
                "trace.parent_id" => root["trace.span_id"],
                "redis.command" => "UNSUBSCRIBE",
              )
            end
          end

          describe "psubscribe + punsubscribe" do
            before do
              expect(connection).to receive(:read).and_return(
                ["psubscribe", "channel", 1],
                %w[message channel hello],
                ["punsubscribe", "channel", 0],
              )
              redis.psubscribe_with_timeout(100, "chan*") do |on|
                on.message { redis.punsubscribe("chan*") }
              end
            end

            it "generates two events" do
              expect(libhoney_client.events.size).to eq 2
            end

            let(:root) { event_data[1] }

            it "sends a psubscribe event" do
              expect(root).to include(
                "meta.span_type" => "root",
                "redis.command" => "PSUBSCRIBE chan*",
              )
            end

            let(:leaf) { event_data[0] }

            it "sends a punsubcribe event" do
              expect(leaf).to include(
                "trace.parent_id" => root["trace.span_id"],
                "redis.command" => "PUNSUBSCRIBE chan*",
              )
            end
          end
        end
      end
    end

    if VERSION >= Gem::Version.new("4.1.0")
      describe "cluster mode", configured: true do
        let(:slots) do
          [[0, 10, ["localhost", 1234, "x"], ["localhost", 2345, "y"]]]
        end

        let(:nodes) do
          "x localhost:1234@x master\r\ny localhost:2345@x slave"
        end

        let(:commands) do
          []
        end

        let(:cluster) do
          %w[redis://localhost:1234 redis://localhost:2345]
        end

        let(:redis) do
          allow(connection).to receive(:read).and_return(slots, nodes, commands)
          Redis.new(driver: driver, cluster: cluster, replica: true).tap do
            libhoney_client.events.clear
          end
        end

        describe "command that runs on all nodes" do
          before { redis.save }

          it "sends an event for each node" do
            expect(libhoney_client.events.size).to eq 2
          end

          it "does not nest the events" do
            expect(event_data).to all include("meta.span_type" => "root")
          end

          it "sends events with shared fields" do
            expect(event_data).to all include("redis.command" => "SAVE")
          end

          it "sends events with individualized fields" do
            locations = event_data.map { |event| event["redis.location"] }
            expect(locations).to contain_exactly(
              "localhost:1234",
              "localhost:2345",
            )
          end
        end

        describe "command that runs on an arbitrary node" do
          before { redis.set("x", 1) }

          it "sends just one event" do
            expect(libhoney_client.events.size).to eq 1
          end

          it "sends the expected fields" do
            expect(event_data.first).to include(
              "meta.span_type" => "root",
              "redis.command" => "SET x 1",
              "redis.location" => /^localhost:(1234|2345)$/,
            )
          end
        end

        describe "command that runs on a master node" do
          before { redis.flushdb }

          it "sends just one event" do
            expect(libhoney_client.events.size).to eq 1
          end

          it "sends the expected fields" do
            expect(event_data.first).to include(
              "meta.span_type" => "root",
              "redis.command" => "FLUSHDB",
              "redis.location" => "localhost:1234",
            )
          end
        end

        describe "command that runs on a replica node" do
          before { redis.keys }

          it "sends just one event" do
            expect(libhoney_client.events.size).to eq 1
          end

          it "sends the expected fields" do
            expect(event_data.first).to include(
              "meta.span_type" => "root",
              "redis.command" => "KEYS *",
              "redis.location" => "localhost:2345",
            )
          end
        end
      end
    end

    describe "distributed mode", configured: true do
      let(:nodes) { %w[redis://localhost:1234 redis://localhost:2345] }
      let(:redis) { Redis::Distributed.new(nodes, driver: driver) }

      describe "command that runs on one node" do
        before { redis.set("x", 1) }

        it "sends just one event" do
          expect(libhoney_client.events.size).to eq 1
        end

        it "sends the expected fields" do
          expect(event_data.first).to include(
            "meta.span_type" => "root",
            "redis.command" => "SET x 1",
            "redis.location" => /^localhost:(1234|2345)$/,
          )
        end
      end

      describe "command that runs on each node" do
        before { redis.keys }

        it "sends an event for each node" do
          expect(libhoney_client.events.size).to eq 2
        end

        it "does not nest the events" do
          expect(event_data).to all include("meta.span_type" => "root")
        end

        it "sends events with shared fields" do
          expect(event_data).to all include("redis.command" => "KEYS *")
        end

        it "sends events with individualized fields" do
          locations = event_data.map { |event| event["redis.location"] }
          expect(locations).to contain_exactly(
            "localhost:1234",
            "localhost:2345",
          )
        end
      end
    end

    describe "command formatting", configured: true do
      subject(:command) { event_data.first["redis.command"] }

      it "escapes backslashes" do
        redis.echo("hi\\ho")
        expect(command).to eq 'ECHO "hi\\\\ho"'
      end

      it "escapes double quotes" do
        redis.echo('hi"ho')
        expect(command).to eq 'ECHO "hi\\"ho"'
      end

      it "escapes newlines" do
        redis.echo("hi\nho")
        expect(command).to eq 'ECHO "hi\\nho"'
      end

      it "escapes carriage returns" do
        redis.echo("hi\rho")
        expect(command).to eq 'ECHO "hi\\rho"'
      end

      it "escapes tabs" do
        redis.echo("hi\tho")
        expect(command).to eq 'ECHO "hi\\tho"'
      end

      it "escapes audible bells" do
        redis.echo("hi\aho")
        expect(command).to eq 'ECHO "hi\\aho"'
      end

      it "escapes backspaces" do
        redis.echo("hi\bho")
        expect(command).to eq 'ECHO "hi\\bho"'
      end

      it "escapes unprintable characters" do
        redis.echo("hi\eho")
        expect(command).to eq 'ECHO "hi\\x1bho"'
      end

      it "escapes digraphs" do
        redis.echo("hi\u00c1ho")
        expect(command).to eq 'ECHO "hi\\xc3\\x81ho"'
      end

      it "escapes trigraphs" do
        redis.echo("hi\u3093ho")
        expect(command).to eq 'ECHO "hi\\xe3\\x82\\x93ho"'
      end

      it "escapes invalid UTF-8" do
        redis.echo("hi\x89ho".encode("UTF-8"))
        expect(command).to eq 'ECHO "hi\\x89ho"'
      end

      it "quotes spaces" do
        redis.echo("hi ho")
        expect(command).to eq 'ECHO "hi ho"'
      end

      it "quotes single quotes" do
        redis.echo("'hi-ho'")
        expect(command).to eq 'ECHO "\'hi-ho\'"'
      end

      it "does not quote printable ASCII characters" do
        redis.echo("hi-ho")
        expect(command).to eq "ECHO hi-ho"
      end
    end
  end
end
