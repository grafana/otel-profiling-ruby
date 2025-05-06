# frozen_string_literal: true

require_relative "lib/pyroscope/otel/version"

Gem::Specification.new do |spec|
  spec.name          = "pyroscope-otel"
  spec.version       = Pyroscope::Otel::VERSION
  spec.authors       = ["Tolyan Korniltsev"]
  spec.email         = ["anatoly@pyroscope.io"]

  spec.summary       = "Pyroscope OTEL integration"
  spec.description   = "Pyroscope OTEL integration"
  spec.homepage      = "https://pyroscope.io/"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/pyroscope-io/otel-profiling-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/pyroscope-io/otel-profiling-ruby/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "opentelemetry-api", "~> 1.1"
  spec.add_dependency "pyroscope", ">= 0.5.1"
end
