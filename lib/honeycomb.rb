# Main entrypoint for the 'honeycomb' gem (see also lib/honeycomb/automagic.rb
# for an alternative entrypoint).

require 'libhoney'

require 'honeycomb/span'

require 'activerecord-honeycomb'
require 'faraday-honeycomb'

module Honeycomb
  class << self
    def init(writekey:, dataset:, options: {})
      options = options.merge(writekey: writekey, dataset: dataset)
      @client = Libhoney::Client.new(options)
    end

    attr_reader :client
  end
end
