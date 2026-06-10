# Pyroscope::Otel

Pyroscope can integrate with distributed tracing systems supporting OpenTelemetry standard which allows you to link traces with the profiling data, and find specific lines of code related to a performance issue.

For full documentation, refer to our [docs](https://grafana.com/docs/pyroscope/latest/configure-client/trace-span-profiles/ruby-span-profiles/).

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
  config.add_span_processor Pyroscope::Otel::SpanProcessor.new
  # Configure the rest of opentelemetry as described  https://github.com/open-telemetry/opentelemetry-ruby
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
