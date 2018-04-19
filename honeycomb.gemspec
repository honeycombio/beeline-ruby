lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH << lib unless $LOAD_PATH.include?(lib)
require 'honeycomb/version'

Gem::Specification.new do |gem|
  gem.name = Honeycomb::GEM_NAME
  gem.version = Honeycomb::VERSION

  gem.summary = 'Instrument your Ruby apps with Honeycomb'
  gem.description = <<-DESC
    TO DO *is* a description
  DESC

  gem.authors = ['Sam Stokes']
  gem.email = %w(sam@honeycomb.io)
  gem.homepage = 'https://github.com/honeycombio/honeycomb-ruby'
  gem.license = 'MIT'


  gem.add_dependency 'libhoney', '>= 1.5.0'

  gem.add_development_dependency 'bump'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'yard'

  gem.files = Dir[*%w(
      lib/**/*
      README*)] & %x{git ls-files -z}.split("\0")
end
