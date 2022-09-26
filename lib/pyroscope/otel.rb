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
      ZERO_SPAN_ID = [0, 0, 0, 0, 0, 0, 0, 0].pack('C*')
      # pyroscope app name, including ".cpu" suffix.
      attr_accessor :app_name
      # http address of pyroscope server for span links
      attr_accessor :pyroscope_endpoint

      #
      attr_accessor :root_span_only
      #
      attr_accessor :add_span_name
      #
      attr_accessor :add_profile_url
      #
      attr_accessor :add_profile_baseline_urls
      #
      attr_accessor :baseline_labels

      # @param [String] app_name - pyroscope app name, including ".cpu" suffix.
      # @param [String] pyroscope_endpoint - http address of pyroscope server for span links.
      def initialize(app_name,
                     pyroscope_endpoint)
        @app_name = app_name
        @pyroscope_endpoint = URI.parse(pyroscope_endpoint)
        @root_span_only = true
        @add_span_name = true
        @add_profile_url = true
        @add_profile_baseline_urls = true
        @baseline_labels = {}
      end

      def on_start(span, _parent_context)
        return if @root_span_only && span.parent_span_id != ZERO_SPAN_ID

        profile_id = profile_id(span)

        labels = { "profile_id": profile_id }
        labels["span"] = span.name if @add_span_name

        Pyroscope._add_tags(Pyroscope.thread_id, labels)

        span.set_attribute("pyroscope.profile.id", profile_id)
        span.set_attribute("pyroscope.profile.url", profile_url(profile_id)) if @add_profile_url
        span.set_attribute("pyroscope.profile.baseline.url", baseline_url(profile_id, "/comparison")) if @add_profile_baseline_urls
        span.set_attribute("pyroscope.profile.diff.url", baseline_url(profile_id, "/diff")) if @add_profile_baseline_urls


      rescue StandardError => e
        OpenTelemetry.handle_error(exception: e, message: "unexpected error in span.on_start")
      end

      def on_finish(span)
        profile_id = span.attributes["pyroscope.profile.id"]
        if profile_id != nil
          labels = { "profile_id": profile_id }
          labels["span"] = span.name if @add_span_name
          Pyroscope._remove_tags(Pyroscope.thread_id, labels)
        end
      end

      def force_flush(_timeout: nil) end

      def shutdown(_timeout: nil) end

      private

      def profile_id(span)
        span.context.span_id.bytes.map { |b| format("%02x", b) }.join
      end

      def profile_url(profile_id)
        query = format("%s{profile_id=\"%s\"}", @app_name, profile_id)
        url = @pyroscope_endpoint.clone
        from = Time.now.to_i
        to = from + 60 * 60
        url.query = URI.encode_www_form({
          "query": query,
          "from": from,
          "until": to
        })
        url.to_s
      end

      def baseline_url(profile_id, path)
        labels = {}
        # Pyroscope.tag_wrapper
        Pyroscope.get_current_tags.each do |k, v|
          if v == "profile_id"
            next
          end
          if @baseline_labels[k] != nil
            next
          end
          labels[k] = v
        end
        @baseline_labels.each do |k, v|
          labels[k] = v
        end
        labels = labels.map { |k, v| "#{k}=\"#{v}\"" }.join(",")
        now = Time.now.to_i
        baseline_query = format("%s{%s}", @app_name, labels)
        profile_id_query = format("%s{profile_id=\"%s\"}", @app_name, profile_id)
        query = URI.encode_www_form({
          "query": baseline_query,
          "from": now - 60 * 60,
          "until": now,
          "leftQuery": baseline_query,
          "leftFrom": now - 60 * 60,
          "leftUntil": now,
          "rightQuery": profile_id_query,
          "rightFrom": now,
          "rightUntil": now + 60 * 60,
        })

        url = @pyroscope_endpoint.clone
        url.path = path
        url.query = query
        url.to_s
      end
    end
  end
end
