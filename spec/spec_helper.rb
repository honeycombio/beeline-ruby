# frozen_string_literal: true

require "bundler/setup"
require "simplecov"
require "simplecov-console"
require "webmock/rspec"
require "pry"

WebMock.disable_net_connect!

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }

SimpleCov.start do
  add_filter "/spec/"
  add_filter "Rakefile"

  add_group "Integrations", "lib/honeycomb/integrations"
  add_group "Propagation", "lib/honeycomb/propagation"
  # Make coverage work with Appraisals
  current_gemfile = ENV.fetch("BUNDLE_GEMFILE", "").split("/").last
  command_name current_gemfile if current_gemfile

  if ENV["CI"]
    coverage_dir("coverage/#{ENV['CIRCLE_JOB']}")
    formatter SimpleCov::Formatter::SimpleFormatter
  else
    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::SimpleFormatter,
        SimpleCov::Formatter::HTMLFormatter,
      ],
    )
  end
end

require "honeycomb-beeline"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # allow :focus to be applied to specific tests for debugging
  config.filter_run_when_matching :focus
end
