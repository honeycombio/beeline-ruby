require "faraday"

class PokeJob < ApplicationJob
  queue_as :default

  def perform(*args)
    seconds_to_sleep = args.first

    Honeycomb.start_span(name: "fakework") do |span|
      span.add_field('app.fakework.sleepytime', seconds_to_sleep)
      sleep seconds_to_sleep
    end

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
