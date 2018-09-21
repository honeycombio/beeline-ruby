# Honeycomb Beeline for Ruby

[![Build Status](https://travis-ci.org/honeycombio/beeline-ruby.svg?branch=master)](https://travis-ci.org/honeycombio/beeline-ruby)
[![Gem Version](https://badge.fury.io/rb/honeycomb-beeline.svg)](https://badge.fury.io/rb/honeycomb-beeline)

This package makes it easy to instrument your Ruby web app to send useful events to [Honeycomb](https://www.honeycomb.io), a service for debugging your software in production.
- [Usage and Examples](https://docs.honeycomb.io/getting-data-in/beelines/ruby-beeline/)

Requires Ruby 2.2 or later. Sign up for a [Honeycomb
trial](https://ui.honeycomb.io/signup) to obtain an API key before starting.

## Installation

Add `honeycomb-beeline` to your Gemfile:

```ruby
gem 'honeycomb-beeline'
```
Now run `bundle install` to install the gem.

## Setup

In your app's startup script - e.g. config.ru or app.rb - add the following
code:

```ruby
require 'honeycomb-beeline'

Honeycomb.init # pulls configuration from the environment - see below
```

## Configuration

You'll need to configure your Honeycomb API key so that your app can
identify itself to Honeycomb. You can find your API key on [your Account
page](https://ui.honeycomb.io/account).

You'll also need to configure the name of a dataset in your Honeycomb account to
send events to. The name of your app is a good choice.

You can specify the configuration either via environment variables, or by
passing arguments to `Honeycomb.init`:

### Configuration via environment variables

 * `HONEYCOMB_WRITEKEY` - specifies the API key (aka "write key")
 * `HONEYCOMB_DATASET` - specifies the dataset
 * `HONEYCOMB_SERVICE` - specifies the name of your app (defaults to the dataset
   name)

### Configuration via code

```ruby
Honeycomb.init(
  writekey: '<MY HONEYCOMB API KEY>',
  dataset: 'my-app',
  service_name: 'my-app'
)
```

Note that Honeycomb API keys have the ability to create and delete data, and
should be managed in the same way as your other application secrets. For example
you might prefer to configure production API keys via environment variables,
rather than checking them into version control.

## Example questions

Now your app is instrumented and sending events, try using Honeycomb to ask
these questions:

 * Which of my app's routes are the slowest?
```
BREAKDOWN: request.path
CALCULATE: P99(duration_ms)
FILTER: type == http_server
ORDER BY: P99(duration_ms) DESC
```
 * Where's my app spending the most time?
```
BREAKDOWN: type
CALCULATE: SUM(duration_ms)
ORDER BY: SUM(duration_ms) DESC
```
 * Which users are using the endpoint that I'd like to deprecate? First add a
   [custom field](#adding-additional-context) `user.email`, then try:
```
BREAKDOWN: app.user.email
CALCULATE: COUNT
FILTER: request.path == /my/deprecated/endpoint
```

## Example event

Here is an example of an `http_server` event (recording that your web app
processed an incoming HTTP request) emitted by the Beeline:

```json
{
  "meta.beeline_version": "0.2.0",
  "meta.local_hostname": "killerbee",
  "service_name": "my-test-app",
  "meta.package": "rack",
  "meta.package_version": "1.3",
  "type": "http_server",
  "name": "GET /dashboard",
  "request.method": "GET",
  "request.path": "/dashboard",
  "request.protocol": "https",
  "request.http_version": "HTTP/1.1",
  "request.host": "my-test-app.example.com",
  "request.remote_addr": "172.217.1.238",
  "request.header.user_agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36",
  "trace.trace_id": "b694512a-833f-4b35-be5f-6c742ba18e12",
  "trace.span_id": "c35cc326-ed90-4881-a4a8-68526d252f2e",
  "response.status_code": 200,
  "duration_ms": 303.057396
}
```

## Adding additional context

The Beeline will automatically instrument your incoming HTTP requests, database
queries and outbound HTTP requests to send events to Honeycomb. However, it can
be very helpful to extend these events with additional context specific to your
app.  You can add your own fields by calling `Rack::Honeycomb.add_field`. For
example, this snippet shows how to associate the currently logged-in user with
each `http_server` event:

```ruby
get '/hello' do
  user = authenticate_user()

  # this will add a custom field 'app.user.email' to the http_server event
  Rack::Honeycomb.add_field(env, 'user.email', user.email)

  "Hello, #{user.name}!"
end
```

## Instrumented packages

The Beeline will automatically send the following events if you are using one of
the listed packages:

### `http_server` (incoming HTTP requests)

* [Sinatra](http://sinatrarb.com) - via [rack-honeycomb](https://github.com/honeycombio/rack-honeycomb)
* Any other [Rack](https://rack.github.io)-based web app - via [rack-honeycomb](https://github.com/honeycombio/rack-honeycomb) (requires manually adding the middleware)

### `db` (database queries)

* [ActiveRecord](https://rubygems.org/gems/activerecord) - via
  [activerecord-honeycomb](https://github.com/honeycombio/activerecord-honeycomb)
* [Sequel](https://sequel.jeremyevans.net/) - via
  [sequel-honeycomb](https://github.com/honeycombio/sequel-honeycomb)

### `http_client` (outbound HTTP requests)

* [Faraday](https://github.com/lostisland/faraday) - via
  [faraday-honeycomb](https://github.com/honeycombio/faraday-honeycomb)

## Known limitations

 * The Beeline will try to autodetect your web framework and automatically
   install its middleware. Currently this only works for Sinatra apps, and
   also fails in some more exotic configurations of Sinatra. If you find you
   aren't seeing any events for processing web requests, you can install the
   [middleware](https://www.rubydoc.info/gems/rack-honeycomb) manually: e.g.
   `use Rack::Honeycomb::Middleware`.
 * Rails apps should work after installing the middleware as above, but are
   currently better supported by our dedicated [Rails
   integration](https://github.com/honeycombio/honeycomb-rails).
 * Alternative concurrency models such as EventMachine or Celluloid are not
   currently supported.

If support for one of these scenarios is important to you, please [let us
know](#get-in-touch)!

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
logger.level = Logger::INFO           # determine how much detail you want to see
Honeycomb.init(logger: logger)
```

A level of `Logger::DEBUG` will show you detail about each library being instrumented,
whereas a level of `Logger::INFO` will just print a few progress messages.

### Get in touch

This beeline is still young, so please reach out to
[support@honeycomb.io](mailto:support@honeycomb.io) or ping us with the chat
bubble on [our website](https://www.honeycomb.io) for assistance.  We also
welcome [bug reports](https://github.com/honeycombio/beeline-ruby/issues) and
[contributions](https://github.com/honeycombio/beeline-ruby/blob/master/CONTRIBUTING.md).
