require 'honeycomb/beeline/version'

require 'libhoney'

require 'logger'
require 'socket'

module Honeycomb
  USER_AGENT_SUFFIX = "#{Beeline::GEM_NAME}/#{Beeline::VERSION}"

  class << self
    attr_reader :client
    attr_reader :logger
    attr_reader :service_name

    # Initialize the Honeycomb Beeline. You should call this only once, as
    # early as possible in your app's startup process, to automatically
    # instrument your app and prepare to send events.
    #
    # @example Providing config in code
    #     Honeycomb.init(
    #       writekey: '0123face4567cafe8901beef2345feed',
    #       dataset: 'myapp-development',
    #       service_name: 'myapp'
    #     )
    # @example Providing config via environment variables
    #     # Assumes environment variables e.g.
    #     #   HONEYCOMB_WRITEKEY=0123face4567cafe8901beef2345feed
    #     #   HONEYCOMB_DATASET=myapp-development
    #     #   HONEYCOMB_SERVICE=myapp
    #
    #     Honeycomb.init
    #
    # @param writekey [String] (required) the Honeycomb API key (aka "write
    #     key") - get yours from your {https://ui.honeycomb.io/account Account
    #     Page}. Can also be specified via the HONEYCOMB_WRITEKEY environment
    #     variable.
    # @param dataset [String] (required) the name of the Honeycomb
    #     {https://docs.honeycomb.io/getting-data-in/datasets/best-practices/
    #     dataset} your app should send events to. Can also be specified via the
    #     HONEYCOMB_DATASET environment variable.
    # @param service_name [String] the name of your app, included in all events
    #     your app will send. Defaults to the dataset name if not specified. Can
    #     also be specified via the HONEYCOMB_SERVICE environment variable.
    # @param debug [Boolean] if true, your app will not send any events to
    #     Honeycomb, but will instead print them to your app's standard error.
    #     It will also log diagnostic messages to standard error.
    # @param logger [Logger] provide a logger to receive diagnostic messages,
    #     e.g. to override the default logging device or verbosity. By default
    #     warnings and above will be logged to standard error; under normal
    #     operation nothing will be logged.
    def init(
      writekey: ENV['HONEYCOMB_WRITEKEY'],
      dataset: ENV['HONEYCOMB_DATASET'],
      service_name: ENV['HONEYCOMB_SERVICE'] || dataset,
      without: [],
      debug: ENV.key?('HONEYCOMB_DEBUG'),
      logger: nil,
      **options
    )
      reset

      @without = without
      @service_name = service_name
      @logger = logger || Logger.new($stderr).tap {|l| l.level = Logger::WARN }
      @debug = debug
      if debug
        @logger ||= Logger.new($stderr)
      end

      options = options.merge(writekey: writekey, dataset: dataset)
      @client = new_client(options)

      after_init_hooks.each do |label, block|
        @logger.debug "Running hook '#{label}' after Honeycomb.init" if @logger
        run_hook(label, block)
      end

      @initialized = true
    end

    # Call at app shutdown to ensure all pending events have been sent to
    # Honeycomb.
    def shutdown
      if defined?(@client) && @client
        @client.close
      end
    end

    # Reset the Beeline to a pristine state, ready to be `.init`ed again.
    # Intended for testing purposes only.
    #
    # @api private
    def reset
      # TODO encapsulate all this into a Beeline object so we don't need
      # explicit cleanup

      shutdown

      @logger = nil
      @without = nil
      @service_name = nil
      @debug = nil
      @client = nil
      @initialized = false
    end

    private
    def after_init_hooks
      @after_init_hooks ||= []
    end

    def new_client(options)
      client = options.delete :client

      options = {user_agent_addition: USER_AGENT_SUFFIX}.merge(options)
      if @debug
        raise ArgumentError, "can't specify both client and debug options", caller if client
        @logger.info 'logging events to standard error instead of sending to Honeycomb' if @logger
        client = Libhoney::LogClient.new(verbose: true, **options)
      else
        client ||= if options[:writekey] && options[:dataset]
          Libhoney::Client.new(options)
        else
          @logger.warn "#{self.name}: no #{options[:writekey] ? 'dataset' : 'writekey'} configured, disabling sending events" if @logger
          Libhoney::NullClient.new(options)
        end
      end
      client.add_field 'meta.beeline_version', Beeline::VERSION
      client.add_field 'meta.local_hostname', Socket.gethostname rescue nil
      client.add_field 'service_name',  @service_name
      client
    end

    def after_init(label, &block)
      raise ArgumentError unless block_given?

      hook = if block.arity == 0
               ->(_, _) { block.call }
             elsif block.arity == 1
               ->(client, _) { block.call client }
             elsif block.arity > 2
               raise ArgumentError, 'Honeycomb.after_init block should take 2 arguments'
             else
               block
             end

      if defined?(@initialized)
        @logger.debug "Running hook '#{label}' as Honeycomb already initialized" if @logger
        run_hook(label, hook)
      else
        after_init_hooks << [label, hook]
      end
    end

    def run_hook(label, block)
      if @without.include?(label)
        @logger.debug "Skipping hook '#{label}' due to opt-out" if @logger
      else
        block.call @client, @logger
      end
    rescue => e
      @logger.warn "Honeycomb.init hook '#{label}' raised #{e.class}: #{e}" if @logger
    end
  end

  after_init :log do |_, logger|
    logger.info "Honeycomb inited" if logger
  end
end
