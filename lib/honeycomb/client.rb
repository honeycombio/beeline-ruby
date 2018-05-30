require 'honeycomb/beeline/version'

require 'libhoney'

require 'socket'

module Honeycomb
  USER_AGENT_SUFFIX = "#{Beeline::GEM_NAME}/#{Beeline::VERSION}"

  class << self
    attr_reader :client
    attr_reader :service_name

    def init(
      writekey: ENV['HONEYCOMB_WRITEKEY'],
      dataset: ENV['HONEYCOMB_DATASET'],
      service_name: ENV['HONEYCOMB_SERVICE'] || dataset,
      without: [],
      logger: nil,
      **options
    )
      reset

      @logger = logger
      @without = without
      @service_name = service_name

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
      client ||= begin
        unless options[:writekey] && options[:dataset]
          raise ArgumentError, "must specify writekey and dataset"
        end
        Libhoney::Client.new(options)
      end
      client.add_field 'meta.beeline_version', Beeline::VERSION
      client.add_field 'meta.local_hostname', Socket.gethostname rescue nil
      client.add_field 'service_name',  @service_name
      client
    end

    def after_init(label, &block)
      raise ArgumentError unless block_given?

      hook = if block.arity == 0
               ->(_) { block.call }
             elsif block.arity > 1
               raise ArgumentError, 'Honeycomb.after_init block should take 1 argument'
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
        block.call @client
      end
    rescue => e
      warn "Honeycomb.init hook '#{label}' raised #{e.class}: #{e}"
    end
  end

  after_init :log do
    @logger.info "Honeycomb inited" if @logger
  end
end
