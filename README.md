# Honeycomb Beeline for Ruby

The Honeycomb Beeline for Ruby is the fastest path to observability for your
Ruby apps. It understands the common packages you use and automatically
instruments them to send useful events to Honeycomb.

## Setup

Setup requires minimal changes to your app, but the approach depends on how your
app loads gems at startup.

### Automatic setup for apps that call `Bundler.require`

If your app calls `Bundler.require` at startup (you can verify by running `git
grep 'Bundler\.require'`) then setup just requires adding one line to your
Gemfile:

```ruby
gem 'honeycomb-beeline', require: 'honeycomb-beeline/auto_install'
```

Now run `bundle install` to install the gem.

### Automatic setup for other apps

If your app does not call `Bundler.require` at startup (you can verify by
running `git grep 'Bundler\.require'`) then you'll need to make two changes.
First add this line to your Gemfile:

```ruby
gem 'honeycomb-beeline'
```

Then require the gem somewhere in your app's startup script - e.g. for a Rack app
add it to your "config.ru":

```ruby
require 'honeycomb-beeline/auto_install'
```

Now run `bundle install` to install the gem.

### Manual setup

If the automatic setup doesn't work for your app, or you prefer to choose which
libraries to instrument, then you'll need to call `Honeycomb.init` manually.

First add this line to your Gemfile:

```ruby
gem 'honeycomb-beeline'
```

Then require and init the gem somewhere in your app's startup script - e.g. for
a Rack app add it to your "config.ru":

```ruby
require 'honeycomb-beeline'

Honeycomb.init(writekey: '<MY HONEYCOMB WRITEKEY>', dataset: 'my-app')
```

Now run `bundle install` to install the gem.

## Configuration

You'll need to configure your Honeycomb writekey so that your app can
identify itself to Honeycomb. You can find your writekey on [your Account
page](https://ui.honeycomb.io/account).

You can also configure which dataset in your Honeycomb account to send events
to. If you don't, the gem will guess the dataset name based on the name of the
current directory.

You can specify the configuration either via environment variables, or by
calling `Honeycomb.init` explicitly:

### Configuration via environment variables

 * `HONEYCOMB_WRITEKEY` - specifies the writekey
 * `HONEYCOMB_DATASET` - specifies the dataset

### Configuration via code

```ruby
Honeycomb.init(writekey: '<MY HONEYCOMB WRITEKEY>', dataset: 'my-app')
```

## Development

### Releasing a new version

Travis will automatically upload tagged releases to Rubygems. To release a new
version, run
```
bump patch --tag   # Or bump minor --tag, etc.
git push --follow-tags
```
