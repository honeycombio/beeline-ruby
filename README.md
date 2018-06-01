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

## Troubleshooting

If you've setup the Beeline as above but you aren't seeing data for your app in
Honeycomb, or you're seeing errors on startup, here are a few things to try:

### Debug mode

To verify the Beeline is working as expected, try running it in debug mode:

```ruby
Honeycomb.init(debug: true)
```

Alternatively, you can also enable debug mode with no code changes by setting
`HONEYCOMB_DEBUG=true` in your environment.

In debug mode, the Beeline will not send any events to Honeycomb, but will
instead print them to your app's standard error. It will also log startup
messages to standard error.

### Logging

By default the Beeline will log errors but otherwise keep quiet. To see more
detail about what it's doing, you can pass a logger object (compliant with the
[stdlib Logger API](https://ruby-doc.org/stdlib-2.4.1/libdoc/logger/rdoc/)) to
`Honeycomb.init`:

```ruby
require 'logger'
logger = Logger.new($stderr)
logger.level = :info           # determine how much detail you want to see
Honeycomb.init(logger: logger)
```

A level of `:debug` will show you detail about each library being instrumented,
whereas a level of `:info` will just print a few progress messages.

### Get in touch

This beeline is still young, so please reach out to
[support@honeycomb.io](mailto:support@honeycomb.io) or ping us with the chat
bubble on [our website](https://www.honeycomb.io){target=_blank} for assistance.
