source 'https://rubygems.org'

gemspec

def local_gem(gem_name, dir: gem_name, **opts)
  project_dir = File.expand_path("../#{dir}", File.dirname(__FILE__))
  if File.directory?(project_dir)
    # override gem dependency from gemspec to use local version instead
    gem gem_name, opts.merge(path: project_dir)
  end
end

group :development do
  local_gem 'activerecord-honeycomb'
  local_gem 'rack-honeycomb'
  local_gem 'faraday-honeycomb'
  local_gem 'sequel-honeycomb'
  local_gem 'libhoney', dir: 'libhoney-rb'

  gem 'pry-byebug'
end
