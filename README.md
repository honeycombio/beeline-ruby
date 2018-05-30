# Honeycomb Beeline for Ruby

The Honeycomb Beeline for Ruby is the fastest path to observability for your
Ruby apps. It understands the common packages you use and automatically
instruments them to send useful events to Honeycomb.

## Setup

Setup requires minimal changes to your app. First add this line to your Gemfile:

```ruby
gem 'honeycomb-beeline'
```

Then in your app's startup script - e.g. for a Rack app "config.ru" is a good
place - add the following code:

```ruby
require 'honeycomb-beeline'

Honeycomb.init
```

Now run `bundle install` to install the gem.

## Configuration

You'll need to configure your Honeycomb writekey so that your app can
identify itself to Honeycomb. You can find your writekey on [your Account
page](https://ui.honeycomb.io/account).

You'll also need to configure the name of a dataset in your Honeycomb account to
send events to. The name of your app is a good choice.

You can specify the configuration either via environment variables, or by
passing arguments to `Honeycomb.init`:

### Configuration via environment variables

 * `HONEYCOMB_WRITEKEY` - specifies the writekey
 * `HONEYCOMB_DATASET` - specifies the dataset
 * `HONEYCOMB_SERVICE` - specifies the name of your app (defaults to the dataset
   name)

### Configuration via code

```ruby
Honeycomb.init(writekey: '<MY HONEYCOMB WRITEKEY>', dataset: 'my-app')
```

Note that you should not check your Honeycomb writekey into version control, as
it is sensitive and allows sending data to your Honeycomb account.

## Development

### Releasing a new version

Travis will automatically upload tagged releases to Rubygems. To release a new
version, run
```
bump patch --tag   # Or bump minor --tag, etc.
git push --follow-tags
```
