#!/usr/bin/env bash

set -uex

if [[ "$BUNDLE_GEMFILE" =~ (rails_41.gemfile|rails_42.gemfile)$ ]]; then
  if [[ "$TRAVIS_RUBY_VERSION" =~ ^(2.3)$ ]]; then
    gem uninstall -v '>= 2' -i $(rvm gemdir) -ax bundler
  elif [[ "$TRAVIS_RUBY_VERSION" =~ ^(2.4|2.5)$ ]]; then
    gem uninstall -v '>= 2' -i $(rvm gemdir)@global -ax bundler
  fi
  gem install bundler -v '< 2'
fi
