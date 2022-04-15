# frozen_string_literal: true

namespace :test do
  task :event_data

  task :name

  desc "this is a description"
  task :description

  task :arguments, %i[a b c]

  task :honeycomb_client do |t|
    t.honeycomb_client.start_span(name: "inner task span") do
      :ok
    end
  end

  task :disabled do
    Honeycomb.start_span(name: "global honeycomb client is still enabled") do
      :ok
    end
  end

  task :custom do |t|
    t.honeycomb_client.start_span(name: "using custom honeycomb client") { :ok }
    Honeycomb.start_span(name: "using global honeycomb client") { :ok }
  end
end
