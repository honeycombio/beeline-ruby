class SchedulePokesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    10.times { |n| PokeJob.perform_later(n) }
  end
end
