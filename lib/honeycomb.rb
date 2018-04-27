# Main entrypoint for the 'honeycomb' gem (see also lib/honeycomb/automagic.rb
# for an alternative entrypoint).

require 'libhoney'

require 'honeycomb/span'
require 'honeycomb/version'

require 'activerecord-honeycomb'
require 'faraday-honeycomb'

module Honeycomb
  USER_AGENT_SUFFIX = "#{GEM_NAME}/#{VERSION}"

  class << self
    def init(writekey:, dataset:, options: {})
      options = options.merge(writekey: writekey, dataset: dataset)
      options = {user_agent_addition: USER_AGENT_SUFFIX}.merge(options)
      @client = Libhoney::Client.new(options)
    end

    attr_reader :client
  end
end
