ARG RUBY_VERSION=3.3.9
FROM ruby:${RUBY_VERSION}

WORKDIR /opt/app

# Copy the gem under test (build context is the repo root).
COPY lib /opt/gem/lib
COPY pyroscope-otel.gemspec /opt/gem/pyroscope-otel.gemspec

COPY integration-test/app/Gemfile ./Gemfile
RUN bundle install

COPY integration-test/app/lib ./lib

ENV APP_ENV=production

# `bundle exec` is required so the `pyroscope-otel` path gem is on the load path.
CMD ["bundle", "exec", "ruby", "lib/main.rb"]
