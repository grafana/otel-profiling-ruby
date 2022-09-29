# Pyroscope::Otel

Pyroscope can integrate with distributed tracing systems supporting OpenTelemetry standard which allows you to link traces with the profiling data, and find specific lines of code related to a performance issue.

For full documentation visit https://pyroscope.io/docs/ruby-tracing/
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pyroscope-otel'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pyroscope-otel

## Usage

```ruby
Pyroscope.configure do |config|
  # Configure pyroscope as described https://pyroscope.io/docs/ruby/
end

OpenTelemetry::SDK.configure do |config|
  config.add_span_processor Pyroscope::Otel::SpanProcessor.new(
    "#{app_name}.cpu", # your app name with ".cpu" suffix, for example rideshare-ruby.cpu
    pyroscope_endpoint # link to your pyroscope server, for example "http://localhost:4040"
  )
  # Configure the rest of opentelemetry as described  https://github.com/open-telemetry/opentelemetry-ruby
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
