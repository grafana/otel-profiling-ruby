# frozen_string_literal: true

require "pyroscope"
# require_relative "otel/version"
require "uri"

module Pyroscope
  module Otel
    class Error < StandardError; end

    # SpanProcessor annotates otel spans with profile_id, profile urls,
    # baseline urls
    class SpanProcessor
      ZERO_SPAN_ID = [0, 0, 0, 0, 0, 0, 0, 0].pack("C*")
      # pyroscope app name, including ".cpu" suffix.
      attr_accessor :app_name
      # http address of pyroscope server for span links
      attr_accessor :pyroscope_endpoint

      # boolean flag option to annotate spans with profile attributes only on root spans.
      attr_accessor :root_span_only
      # boolean flag option to annotate pyroscope profiles with span name
      attr_accessor :add_span_name
      # boolean flag option to add profiler url to span attributes
      attr_accessor :add_url
      # boolean flag option to add profiler url to span attributes
      attr_accessor :add_baseline_urls
      # extra set of labels for baseline urls
      attr_accessor :baseline_labels

      # @param [String] app_name - pyroscope app name, including ".cpu" suffix.
      # @param [String] pyroscope_endpoint - http address of pyroscope server for span links.
      def initialize(app_name,
                     pyroscope_endpoint)
        @app_name = app_name
        @pyroscope_endpoint = URI.parse(pyroscope_endpoint)
        @root_span_only = true
        @add_span_name = true
        @add_url = true
        @add_baseline_urls = true
        @baseline_labels = {}
      end

      def on_start(span, _parent_context)
        return if @root_span_only && span.parent_span_id != ZERO_SPAN_ID

        profile_id = profile_id(span)

        labels = { "profile_id": profile_id }
        labels["span"] = span.name if @add_span_name

        Pyroscope._add_tags(Pyroscope.thread_id, labels)

        annotate_span(profile_id, span)
      rescue StandardError => e
        OpenTelemetry.handle_error(exception: e, message: "unexpected error in span.on_start")
      end

      def on_finish(span)
        profile_id = span.attributes["pyroscope.profile.id"]
        return if profile_id.nil?

        labels = { "profile_id": profile_id }
        labels["span"] = span.name if @add_span_name
        Pyroscope._remove_tags(Pyroscope.thread_id, labels)
      end

      def force_flush(_timeout: nil) end

      def shutdown(_timeout: nil) end

      private

      def annotate_span(profile_id, span)
        span.set_attribute("pyroscope.profile.id", profile_id)
        span.set_attribute("pyroscope.profile.url", profile_url(profile_id)) if @add_url

        return unless @add_baseline_urls

        span.set_attribute("pyroscope.profile.baseline.url", baseline_url(profile_id, "/comparison"))
        span.set_attribute("pyroscope.profile.diff.url", baseline_url(profile_id, "/diff"))
      end

      def profile_id(span)
        span.context.span_id.bytes.map { |b| format("%02x", b) }.join
      end

      def profile_url(profile_id)
        url = @pyroscope_endpoint.clone
        from = Time.now.to_i
        to = from + 60 * 60
        url.query = URI.encode_www_form({
                                          "query": query(profile_id),
                                          "from": from,
                                          "until": to
                                        })
        url.to_s
      end

      def baseline_url(profile_id, path)
        now = Time.now.to_i
        query = URI.encode_www_form({ "query": baseline_query, "from": now - 60 * 60, "until": now,
                                      "leftQuery": baseline_query, "leftFrom": now - 60 * 60, "leftUntil": now,
                                      "rightQuery": query(profile_id), "rightFrom": now, "rightUntil": now + 60 * 60 })
        url = @pyroscope_endpoint.clone
        url.path = path
        url.query = query
        url.to_s
      end

      def query(profile_id)
        format("%<app_name>s{profile_id=\"%<profile_id>s\"}", { app_name: @app_name,
                                                                profile_id: profile_id })
      end

      def baseline_query
        labels = Pyroscope.get_current_tags.filter { |k, _| k != "profile_id" && @baseline_labels[k].nil? }
        @baseline_labels.each { |k, v| labels[k] = v }
        labels = labels.map { |k, v| "#{k}=\"#{v}\"" }.join(",")
        format("%<app_name>s{%<labels>s}", { app_name: @app_name, labels: labels })
      end
    end
  end
end
