# frozen_string_literal: true

require "pyroscope"
# require_relative "otel/version"

module Pyroscope
  module Otel
    class Error < StandardError; end

    # SpanProcessor annotates otel spans with profile_id
    class SpanProcessor
      ZERO_SPAN_ID = [0, 0, 0, 0, 0, 0, 0, 0].pack("C*")

      def on_start(span, parent_context)
        return unless root_span?(span, parent_context)

        profile_id = profile_id(span)

        Pyroscope._add_tags({ "profile_id": profile_id, "span": span.name, "trace_id": trace_id(span) })

        annotate_span(profile_id, span)
      rescue StandardError => e
        OpenTelemetry.handle_error(exception: e, message: "unexpected error in span.on_start")
      end

      def on_finish(span)
        profile_id = span.attributes["pyroscope.profile.id"]
        return if profile_id.nil?

        Pyroscope._remove_tags({ "profile_id": profile_id, "span": span.name, "trace_id": trace_id(span) })
      end

      def force_flush(*)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      def shutdown(*)
        OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      private

      def root_span?(parent, parent_context)
        return true if parent.parent_span_id == ZERO_SPAN_ID

        parent = OpenTelemetry::Trace.current_span(parent_context)
        return false if parent.nil?

        parent.context.remote?
      rescue StandardError => _e
        false
      end

      def annotate_span(profile_id, span)
        span.set_attribute("pyroscope.profile.id", profile_id)
      end

      def profile_id(span)
        span.context.span_id.unpack1("H*")
      end

      def trace_id(span)
        span.context.trace_id.unpack1("H*")
      end
    end
  end
end
