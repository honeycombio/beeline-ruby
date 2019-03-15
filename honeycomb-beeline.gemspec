# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "honeycomb/beeline/version"

Gem::Specification.new do |spec|
  spec.name          = "honeycomb-beeline"
  spec.version       = Honeycomb::Beeline::VERSION
  spec.authors       = ["Martin Holman"]
  spec.email         = ["martin@honeycomb.io"]

  spec.summary       = "Instrument your Ruby apps with Honeycomb"
  spec.homepage      = "https://honeycomb.io"

  spec.required_ruby_version = ">= 2.2.0"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/honeycombio/beeline-ruby"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path("..", __dir__)) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.match(%r{^(test|spec|features)/})
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "libhoney", "~> 1.8"

  spec.add_development_dependency "bump"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "faraday"
  spec.add_development_dependency "overcommit", "~> 0.46.0"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rack-test", "~> 1.1.0"
  spec.add_development_dependency "rails"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.65.0"
  spec.add_development_dependency "sequel"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-console"
  spec.add_development_dependency "sinatra"
  spec.add_development_dependency "webmock"
end
