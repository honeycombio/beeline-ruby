# Alternative entrypoint for the 'honeycomb' gem that detects libraries we can
# instrument and automagically instrument them.

require 'libhoney'

require 'honeycomb/span'
require 'honeycomb/version'

module Honeycomb
  USER_AGENT_SUFFIX = "#{GEM_NAME}/#{VERSION}"

  class << self
    attr_reader :client

    def after_init(label, &block)
      raise ArgumentError unless block_given?

      hook = if block.arity == 0
               ->(_) { block.call }
             elsif block.arity > 1
               raise ArgumentError, 'Honeycomb.after_init block should take 1 argument'
             else
               block
             end

      if @initialized
        puts "Running hook '#{label}' as Honeycomb already initialized"
        run_hook(label, hook)
      else
        after_init_hooks << [label, hook]
      end
    end

    def init(writekey:, dataset:, options: {})
      options = options.merge(writekey: writekey, dataset: dataset)
      options = {user_agent_addition: USER_AGENT_SUFFIX}.merge(options)
      @client = Libhoney::Client.new(options)

      after_init_hooks.each do |label, block|
        puts "Running hook '#{label}' after Honeycomb.init"
        run_hook(label, block)
      end
    ensure
      @initialized = true
    end

    private
    def after_init_hooks
      @after_init_hooks ||= []
    end

    def run_hook(label, block)
      block.call @client
    rescue => e
      warn "Honeycomb.init hook '#{label}' raised #{e.class}: #{e}"
    end
  end

  after_init :spam do
    puts "Honeycomb inited"
  end

  # things to try autoinstrumenting:
  #  * rack - nope
end

require 'activerecord-honeycomb/automagic'
require 'faraday-honeycomb/automagic'
require 'rack-honeycomb/automagic'

require 'honeycomb/env_config'
if Honeycomb::ENV_CONFIG
  Honeycomb.init(Honeycomb::ENV_CONFIG)
end
