# frozen_string_literal: true

require "bundler/setup"
require "simplecov"
require "simplecov-console"
require "webmock/rspec"
require "pry"

WebMock.disable_net_connect!

Dir["./spec/support/**/*.rb"].sort.each { |f| require f }
SimpleCov.formatter = SimpleCov::Formatter::Console

# Make coverage work with Appraisals
SimpleCov.command_name(ENV["BUNDLE_GEMFILE"].split.last || "")

SimpleCov.start do
  add_filter "/spec/"
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
end
