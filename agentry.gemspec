# frozen_string_literal: true

require_relative "lib/browser/version"

Gem::Specification.new do |s|
  s.name = "agentry"
  s.version = Browser::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Nando Vieira", "Level UP Solutions"]
  s.homepage = "https://github.com/levups/agentry"
  s.summary = "Browser detection for Ruby: the browser gem's API, faster"
  s.description = "A drop-in replacement for the browser gem: the same Browser API and require paths, " \
                  "answering nearly twice as fast with half the allocations."
  s.license = "MIT"
  s.required_ruby_version = ">= 3.3"

  s.metadata["rubygems_mfa_required"] = "true"
  s.metadata["source_code_uri"] = s.homepage
  s.metadata["changelog_uri"] = "#{s.homepage}/blob/main/CHANGELOG.md"
  s.metadata["documentation_uri"] = "https://levups.github.io/agentry/"
  s.metadata["bug_tracker_uri"] = "#{s.homepage}/issues"

  s.files = Dir["lib/**/*.rb", "data/*.json", "test/ua*.yml",
    "README.md", "LICENSE.md", "CHANGELOG.md"]
  s.require_paths = ["lib"]

  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-utils"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rails"
  s.add_development_dependency "rake"
  s.add_development_dependency "rubocop-performance"
  s.add_development_dependency "standard"
  s.add_development_dependency "simplecov", ">= 1.0"
end
