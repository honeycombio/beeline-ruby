require 'honeykiq/periodic_reporter'

class SidekiqReportJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Honeykiq::PeriodicReporter.new.report do |_type|
      { 'name': 'sidekiq_stats'}
    end
  end
end
