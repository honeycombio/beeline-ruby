lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH << lib unless $LOAD_PATH.include?(lib)
require 'honeycomb/beeline/version'

Gem::Specification.new do |gem|
  gem.name = Honeycomb::Beeline::GEM_NAME
  gem.version = Honeycomb::Beeline::VERSION

  gem.summary = 'Instrument your Ruby apps with Honeycomb'
  gem.description = <<-DESC
    The Honeycomb Beeline for Ruby is the fastest path to observability for your
    Ruby apps. It understands the common packages you use and automatically
    instruments them to send useful events to Honeycomb.
  DESC

  gem.authors = ['Sam Stokes']
  gem.email = %w(sam@honeycomb.io)
  gem.homepage = 'https://github.com/honeycombio/beeline-ruby'
  gem.license = 'MIT'


  gem.add_dependency 'libhoney', '>= 1.6.0'

  gem.add_dependency 'activerecord-honeycomb', '>= 0.2.1'
  gem.add_dependency 'rack-honeycomb', '>= 0.2.1'
  gem.add_dependency 'faraday-honeycomb', '>= 0.2.1'
  gem.add_dependency 'sequel-honeycomb', '>= 0.2.1'
  # TODO
  # gem.add_dependency 'honeycomb-rails'


  gem.add_development_dependency 'activerecord'
  gem.add_development_dependency 'bump'
  gem.add_development_dependency 'faraday'
  gem.add_development_dependency 'pg'
  gem.add_development_dependency 'rack'
  gem.add_development_dependency 'rack-test'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'sinatra'
  gem.add_development_dependency 'sequel'
  gem.add_development_dependency 'yard'

  gem.files = Dir[*%w(
      lib/**/*
      README*)] & %x{git ls-files -z}.split("\0")
end
