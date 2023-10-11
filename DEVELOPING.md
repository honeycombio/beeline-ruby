# Local Development

## Requirements

Ruby: <https://www.ruby-lang.org/en/documentation/installation/>

Rake:

```shell
gem install rake
```

## Install dependencies

```shell
bundle install
```

## Run Tests

To run all tests:

```shell
bundle exec rake test
```

To run individual tests:

```shell
bundle exec rake test TEST=spec/honeycomb/trace_spec.rb
```
