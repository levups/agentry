# frozen_string_literal: true

require "./lib/browser/version"

Gem::Specification.new do |s|
  s.name = "browserx"
  s.version = Browser::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Nando Vieira", "Level UP Solutions"]
  s.homepage = "https://github.com/next-gen-gems/browserx"
  s.summary = "Browser detection for Ruby: the browser gem's API, faster"
  s.description = s.summary
  s.license = "MIT"
  s.required_ruby_version = ">= 3.3"

  s.metadata["rubygems_mfa_required"] = "true"
  s.metadata["source_code_uri"] = "https://github.com/next-gen-gems/browserx"
  s.metadata["changelog_uri"] = "https://github.com/next-gen-gems/browserx/blob/main/CHANGELOG.md"
  s.metadata["documentation_uri"] = "https://next-gen-gems.github.io/browserx/"

  s.files = Dir["lib/**/*.rb", "*.yml", "test/ua*.yml",
    "README.md", "LICENSE.md", "CHANGELOG.md"]
  s.require_paths = ["lib"]

  s.add_development_dependency "minitest"
  s.add_development_dependency "minitest-utils"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rails"
  s.add_development_dependency "rake"
  s.add_development_dependency "rubocop-performance"
  s.add_development_dependency "standard"
  s.add_development_dependency "simplecov"
end
