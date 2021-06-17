schedule_file = "config/job_schedule.yml"

if File.exist?(schedule_file) && Sidekiq.server?
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end

# Add Honeykiq instrumentation to Sidekiq's middleware chains.
#   - https://github.com/carwow/honeykiq
# Several Honeycomb users have used the Honeykiq library--open
# source and community-maintained--to successfully instrument
# their Sidekiq-run background jobs.
Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
     # tracing_mode: options are :link or :child
     # - :link will use link events https://docs.honeycomb.io/getting-data-in/tracing/send-trace-data/#links
     # - :child will use add the job as a span to the enqueing trace
    # :child used here to clearly roll-up jobs spawns from other jobs
    chain.add Honeykiq::ServerMiddleware, tracing_mode: :child
  end

  config.client_middleware do |chain|
    chain.add Honeykiq::ClientMiddleware
  end
end

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Honeykiq::ClientMiddleware
  end
end
