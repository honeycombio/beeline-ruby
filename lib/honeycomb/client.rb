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

    def shutdown
      if defined?(@client) && @client
        @client.close
      end
    end

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
