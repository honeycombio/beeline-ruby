# frozen_string_literal: true

namespace :test do
  task :event_data

  task :name

  desc "this is a description"
  task :description

  task :arguments, %i[a b c]

  namespace :client do
    task :access do |t|
      t.honeycomb_client.start_span(name: "inner task span") { :ok }
    end

    task :enabled

    task disabled: :enabled do
      Honeycomb.start_span(name: "global honeycomb client is still enabled") { :ok }
    end

    task :default do
      Honeycomb.start_span(name: "global honeycomb client") { :ok } if Honeycomb.client
    end

    task custom: :default
  end
end
