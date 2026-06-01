# frozen_string_literal: true

require "bundler/gem_tasks"

# release-please already creates the git tag and GitHub release. The
# rubygems/release-gem action runs `bundle exec rake release`, which would
# otherwise try to `git push` — that fails in CI because the repo is checked
# out at a detached SHA with no credentials. Skip the SCM push and let
# `rake release` only publish the gem to rubygems.org.
module Bundler
  class GemHelper
    def perform_git_push(*); end
  end
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]
