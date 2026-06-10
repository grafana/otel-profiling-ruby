# frozen_string_literal: true

require "pyroscope"
require "pyroscope/otel"
require "opentelemetry-sdk"

app_name = ENV.fetch("PYROSCOPE_APPLICATION_NAME", "rideshare.ruby.app")
server = ENV.fetch("PYROSCOPE_SERVER_ADDRESS", "http://pyroscope:4040")

Pyroscope.configure do |config|
  config.app_name = app_name
  config.server_address = server
  config.tags = {
    "region": ENV.fetch("REGION", "us-east")
  }
end

# Print the underlying cause of any configuration error so failures are
# diagnosable from the container logs instead of the opaque SDK wrapper.
OpenTelemetry.error_handler = lambda do |exception:, message:|
  warn "OpenTelemetry error: #{message}"
  if exception
    warn "  #{exception.class}: #{exception.message}"
    cause = exception.cause
    if cause
      warn "  caused by #{cause.class}: #{cause.message}"
      warn cause.backtrace.first(15).map { |l| "    #{l}" }.join("\n") if cause.backtrace
    end
  end
end

OpenTelemetry::SDK.configure do |c|
  c.add_span_processor Pyroscope::Otel::SpanProcessor.new("#{app_name}.cpu", server)
end

provider = OpenTelemetry.tracer_provider
unless provider.is_a?(OpenTelemetry::SDK::Trace::TracerProvider)
  warn "FATAL: OpenTelemetry SDK did not configure; tracer_provider=#{provider.class}. Spans will not be recorded."
  exit 1
end

# spin busy-loops for roughly `seconds` so the CPU profiler captures the frame.
def spin(seconds)
  start = Time.now
  i = 0
  i += 1 while Time.now - start < seconds
  i
end

def check_driver_availability(seconds)
  spin(seconds / 2.0)
end

def find_nearest_vehicle(seconds, vehicle)
  Pyroscope.tag_wrapper({ "vehicle" => vehicle }) do
    spin(seconds)
    check_driver_availability(seconds) if vehicle == "car"
  end
end

def order_bike(seconds)
  find_nearest_vehicle(seconds, "bike")
end

def order_scooter(seconds)
  find_nearest_vehicle(seconds, "scooter")
end

def order_car(seconds)
  find_nearest_vehicle(seconds, "car")
end

tracer = OpenTelemetry.tracer_provider.tracer("rideshare")

puts "rideshare ruby app started: app_name=#{app_name} server=#{server}"
$stdout.flush

loop do
  tracer.in_span("BikeHandler") { order_bike(0.2) }
  tracer.in_span("ScooterHandler") { order_scooter(0.3) }
  tracer.in_span("CarHandler") { order_car(0.4) }
end
