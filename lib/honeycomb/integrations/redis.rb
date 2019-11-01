# frozen_string_literal: true

require "redis"

module Honeycomb
  module Redis
    # Patches Redis with the option to configure the Honeycomb client.
    #
    # When you load this integration, each Redis call will be wrapped in a span
    # containing information about the command being invoked.
    #
    # This module automatically gets mixed into the Redis class so you can
    # change the underlying {Honeycomb::Client}. By default, we use the global
    # {Honeycomb.client} to send events. A nil client will disable the
    # integration altogether.
    #
    # @example Custom client
    #   Redis.honeycomb_client = Honeycomb::Client.new(...)
    #
    # @example Disabling instrumentation
    #   Redis.honeycomb_client = nil
    module Configuration
      attr_writer :honeycomb_client

      def honeycomb_client
        @honeycomb_client || Honeycomb.client
      end
    end

    # Patches Redis::Client with Honeycomb instrumentation.
    #
    # Circa versions 3.x and 4.x of their gem, the Redis class is backed by an
    # underlying Redis::Client object. The methods used to send commands to the
    # Redis server - namely Redis::Client#call, Redis::Client#call_loop,
    # Redis::Client#call_pipeline, Redis::Client#call_pipelined,
    # Redis::Client#call_with_timeout, and Redis::Client#call_without_timeout -
    # all eventually wind up calling the Redis::Client#process method to do the
    # "dirty work" of writing commands out to an underlying connection. So this
    # gives us a single point of entry that's ideal for introducing the
    # Honeycomb span.
    #
    # An alternative interface provided since at least version 3.0.0 is
    # Redis::Distributed. Underneath, though, it maintains a collection of
    # Redis objects, and each call is forwarded to one or more members of the
    # collection. So patching Redis::Client still captures spans originating
    # from Redis::Distributed. Typical commands (i.e., ones that aren't
    # "global" like `QUIT` or `FLUSHALL`) forward to just a single node anyway,
    # so there's not much use to wrapping everything up in a span for the
    # Redis::Distributed method call.
    #
    # Another alternative interface provided since v4.0.3 is Redis::Cluster,
    # which you can configure the Redis class to use instead of Redis::Client.
    # Again, though, Redis::Cluster maintains a collection of Redis::Client
    # instances underneath. The tracing needs wind up being pretty much the
    # same as Redis::Distributed, even though the actual architecture is
    # significantly different.
    #
    # An implementation detail of pub/sub commands since v2.0.0 (well below our
    # supported version of the redis gem!) is Redis::SubscribedClient, but that
    # still wraps an underlying Redis::Client or Redis::Cluster instance.
    #
    # @see https://github.com/redis/redis-rb/blob/2e8577ad71d0efc32f31fb034f341e1eb10abc18/lib/redis/client.rb#L77-L180
    #   Relevant Redis::Client methods circa v3.0.0
    # @see https://github.com/redis/redis-rb/blob/a2c562c002bc8f86d1f47818d63db2da1c5c3d3f/lib/redis/client.rb#L124-L239
    #   Relevant Redis::Client methods circa v4.1.3
    # @see https://github.com/redis/redis-rb/commits/master/lib/redis/client.rb
    #   History of Redis::Client
    #
    # @see https://redis.io/topics/partitioning
    #   Partitioning (the basis for Redis::Distributed)
    # @see https://github.com/redis/redis-rb/blob/2e8577ad71d0efc32f31fb034f341e1eb10abc18/lib/redis/distributed.rb
    #   Redis::Distributed circa v3.0.0
    # @see https://github.com/redis/redis-rb/blob/a2c562c002bc8f86d1f47818d63db2da1c5c3d3f/lib/redis/distributed.rb
    #   Redis::Distributed circa v4.1.3
    # @see https://github.com/redis/redis-rb/commits/master/lib/redis/distributed.rb
    #   History of Redis::Distributed
    #
    # @see https://redis.io/topics/cluster-spec
    #   Clustering (the basis for Redis::Cluster)
    # @see https://github.com/redis/redis-rb/commit/7f48c0b02fa89256167bc481a73ce2e0c8cca89a
    #   Initial implementation of Redis::Cluster released in v4.0.3
    # @see https://github.com/redis/redis-rb/blob/a2c562c002bc8f86d1f47818d63db2da1c5c3d3f/lib/redis/cluster.rb
    #   Redis::Cluster circa v4.1.3
    # @see https://github.com/redis/redis-rb/commits/master/lib/redis/cluster.rb
    #   History of Redis::Cluster
    #
    # @see https://redis.io/topics/pubsub
    #   Pub/Sub in Redis
    # @see https://github.com/redis/redis-rb/blob/17d40d80388b536ec53a8f19bb1404e93a61650f/lib/redis/subscribe.rb
    #   Redis::SubscribedClient circa v2.0.0
    # @see https://github.com/redis/redis-rb/blob/2e8577ad71d0efc32f31fb034f341e1eb10abc18/lib/redis/subscribe.rb
    #   Redis::SubscribedClient circa v3.0.0
    # @see https://github.com/redis/redis-rb/blob/a2c562c002bc8f86d1f47818d63db2da1c5c3d3f/lib/redis/subscribe.rb
    #   Redis::SubscribedClient circa v4.1.3
    module Client
      def process(commands)
        return super if ::Redis.honeycomb_client.nil?

        span = ::Redis.honeycomb_client.start_span(name: "redis")
        begin
          fields = Fields.new(self)
          fields.options = @options
          fields.command = commands
          span.add fields
          super
        rescue StandardError => e
          span.add_field "redis.error", e.class.name
          span.add_field "redis.error_detail", e.message
          raise
        ensure
          span.send
        end
      end
    end

    # This structure contains the fields we'll add to each Redis span.
    #
    # The logic is in this class to avoid monkey-patching extraneous APIs into
    # the Redis::Client via {Client}.
    #
    # @private
    class Fields
      def initialize(client)
        @client = client
      end

      def options=(options)
        options.each do |option, value|
          values["redis.#{option}"] ||= value unless ignore?(option)
        end
      end

      def command=(commands)
        commands = Array(commands)
        values["redis.command"] = commands.map { |cmd| format(cmd) }.join("\n")
      end

      def to_hash
        values
      end

      private

      def values
        @values ||= {
          "meta.package" => "redis",
          "meta.package_version" => ::Redis::VERSION,
          "redis.id" => @client.id,
          "redis.location" => @client.location,
        }
      end

      # Do we ignore this Redis::Client option?
      #
      # * :url - unsafe because it might contain a password
      # * :password - unsafe
      # * :logger - just some Ruby object, not useful
      # * :_parsed - implementation detail
      def ignore?(option)
        %i[url password logger _parsed].include?(option)
      end

      def format(cmd)
        name, *args = cmd.flatten(1)
        name = resolve(name)
        sanitize(args) if name.casecmp("auth").zero?
        [name.upcase, *args.map { |arg| prettify(arg) }].join(" ")
      end

      def resolve(name)
        @client.command_map.fetch(name, name).to_s
      end

      def sanitize(args)
        args.map! { "[sanitized]" }
      end

      def prettify(arg)
        quotes = false
        pretty = "".dup
        arg.to_s.each_char do |c|
          quotes ||= needs_quotes?(c)
          pretty << escape(c)
        end
        quotes ? "\"#{pretty}\"" : pretty
      end

      ESCAPES = {
        "\\" => "\\\\",
        '"' => '\\"',
        "\n" => "\\n",
        "\r" => "\\r",
        "\t" => "\\t",
        "\a" => "\\a",
        "\b" => "\\b",
      }.freeze

      # This aims to replicate the algorithm used by redis-cli.
      #
      # @see https://github.com/antirez/redis/blob/0f026af185e918a9773148f6ceaa1b084662be88/src/sds.c#L940-L1067
      # @see https://github.com/antirez/redis/blob/0f026af185e918a9773148f6ceaa1b084662be88/src/sds.c#L878-L907
      def escape(char)
        if ESCAPES.key?(char)
          ESCAPES[char]
        elsif char =~ /[[:print:]&&[:ascii:]]/
          char
        else
          bytes = char.unpack("H*").pack("H*").bytes
          bytes.map { |b| Kernel.format("\\x%02x", b) }.join
        end
      end

      def needs_quotes?(char)
        char =~ /[^[:print:]&&[:ascii:]]|[\\"\n\r\t\a\b' ]/
      end
    end
  end
end

Redis.extend(Honeycomb::Redis::Configuration)
Redis::Client.prepend(Honeycomb::Redis::Client)
