#!/usr/bin/env bash

set -ux

if [[ "$BUNDLE_GEMFILE" =~ (rails_41.gemfile|rails_42.gemfile)$ ]]; then
  gem uninstall -v '>= 2' -i $(rvm gemdir) -ax bundler
  gem uninstall -v '>= 2' -i $(rvm gemdir)@global -ax bundler
  gem install bundler -v '< 2'
fi
