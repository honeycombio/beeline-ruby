# Alternative entrypoint for the 'honeycomb' gem that detects libraries we can
# instrument and automagically instrument them.

require 'libhoney'

require 'honeycomb/span'

module Honeycomb
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
  #  * sinatra
  after_init(:sinatra) do |client|
    require 'sinatra/base'
    require 'rack/honeycomb'

    class << ::Sinatra::Base
      alias build_without_honeycomb build
    end

    ::Sinatra::Base.define_singleton_method(:build) do |*args, &block|
      if defined?(@@honeycomb_already_added)
        puts "#{self} chained build"
        unless @@honeycomb_already_added == :warned
          warn "Honeycomb Sinatra instrumentation will probably not work, try manual installation"
          @@honeycomb_already_added = :warned
        end
      else
        puts "#{self} chained build adding Honeycomb"
        self.use Rack::Honeycomb::Middleware, client: client
        @@honeycomb_already_added = true
      end
      build_without_honeycomb(*args, &block)
    end
  end # TODO if false # compound apps mess this up
  #  * faraday
  after_init(:faraday) do |client|
    require 'faraday'
    require 'faraday-honeycomb'

    Faraday::Connection.extend(Module.new do
      define_method :new do |*args|
        puts "Faraday overridden .new before super"
        block = if block_given?
                  proc do |b|
                    b.use :honeycomb, client: client
                    yield b
                  end
                else
                  proc do |b|
                    b.use :honeycomb, client: client
                    b.adapter Faraday.default_adapter
                  end
                end
        super(*args, &block).tap do
          puts "Faraday overridden .new after super"
        end
      end
    end)
  end
end

require 'activerecord-honeycomb/automagic'
