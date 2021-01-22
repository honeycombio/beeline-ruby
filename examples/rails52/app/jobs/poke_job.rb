require "faraday"

class PokeJob < ApplicationJob
  queue_as :default

  def perform(*args)
    sleep args.first
    uri = "http://web:3000/"
    begin
      Faraday.get(uri) do |request|
        request.headers['User-Agent'] = 'rails52 example / Poke background job'
      end
    rescue => exception
      puts "Nope. #{uri} didn't work."
    end
  end
end
