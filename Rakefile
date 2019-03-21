# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "appraisal"

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new(:rubocop)

task test: :spec

task default: %i[rubocop spec]

!ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"] && task(default: :appraisal)
