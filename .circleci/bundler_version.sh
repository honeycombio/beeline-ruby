#!/usr/bin/env bash

set -ux

if [[ "$BUNDLE_GEMFILE" =~ (rails_41.gemfile|rails_42.gemfile)$ ]]; then
  gem uninstall -v '>= 2' -ax bundler
  gem install bundler -v '< 2'
fi
