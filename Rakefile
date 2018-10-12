require 'active_record'
require 'bump/tasks'
require 'rspec/core/rake_task'
require 'yaml'
require 'yard'

$db_dir = 'spec/db'

YARD::Rake::YardocTask.new(:doc)

namespace :spec do
  namespace :db do
    include ActiveRecord::Tasks

    task :config do
      db_config = YAML.load_file("#$db_dir/config-activerecord.yml")

      DatabaseTasks.database_configuration = db_config
      DatabaseTasks.env = 'test'
      DatabaseTasks.root = 'spec'
      DatabaseTasks.db_dir = $db_dir
      ActiveRecord::Base.configurations = db_config
    end

    desc 'Create the test database'
    task create: :config do
      DatabaseTasks.create_current
    end

    desc 'Delete the test database'
    task drop: :config do
      DatabaseTasks.drop_current
    end

    desc 'Set up the test database from schema.rb'
    task load_schema: :config do
      DatabaseTasks.load_schema_current(:ruby, nil)
    end
  end

  TEST_APPS = %i(
    sinatra_activerecord
    sinatra_sequel
    rails_activerecord
  )

  TEST_APPS.each do |app|
    desc "Run specs for #{app} test app"
    RSpec::Core::RakeTask.new(app) do |t|
      t.rspec_opts = "--pattern spec/instrumented_apps/#{app}/**/*_spec.rb"
    end
  end

  desc 'Run specs for Beeline operation'
  RSpec::Core::RakeTask.new(:beeline) do |t|
    t.rspec_opts = '--pattern spec/beeline/**/*_spec.rb'
  end

  task all: TEST_APPS + [:beeline]
end

desc 'Run all specs'
task spec: 'spec:all'

task default: :spec
