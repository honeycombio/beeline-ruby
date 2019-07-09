# frozen_string_literal: true

namespace :test do
  desc "used by integration_spec to test rake integration"
  task :perform do |task|
    task.honeycomb_client.start_span(name: "inner task span") do
      # nothing to do here...
    end
  end
end
