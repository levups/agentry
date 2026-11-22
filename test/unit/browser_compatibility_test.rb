# frozen_string_literal: true

require "test_helper"
require "open3"

class BrowserCompatibilityTest < Minitest::Test
  LIB_PATH = File.expand_path("../../lib", __dir__)
  ACTIVATE_BROWSER_GEM = 'Gem.loaded_specs["browser"] = Gem::Specification.new("browser", "6.2.0")'

  def run_ruby(*scripts)
    arguments = scripts.flat_map { ["-e", _1] }
    Open3.capture3(RbConfig.ruby, "-W:deprecated", "-I", LIB_PATH, *arguments)
  end

  test "require \"agentry\" defines no Browser" do
    output, errors, status = run_ruby('require "agentry"', "print defined?(Browser).inspect")

    assert status.success?, errors
    assert_equal "nil", output
    assert_empty errors
  end

  {
    "agentry/agentry" => 'Agentry.new("").name',
    "agentry/aliases" => "Agentry::Aliases::DEVICE_ALIASES.size",
    "agentry/testing" => 'Agentry["CHROME"]',
    "agentry/rails" => 'Agentry.new("").name'
  }.each do |path, call|
    test "require #{path.inspect} alone is enough to call Agentry" do
      _output, errors, status = run_ruby(%(require "#{path}"), call)

      assert status.success?, errors
      assert_empty errors
    end
  end

  test "loads next to the browser gem" do
    _output, errors, status = run_ruby(ACTIVATE_BROWSER_GEM, 'require "agentry"')

    assert status.success?, errors
  end

  test "the browser require paths refuse to load next to the browser gem" do
    _output, errors, status = run_ruby(ACTIVATE_BROWSER_GEM, 'require "browser/browser"')

    refute status.success?
    assert_includes errors, "which the browser gem defines too"
  end

  %w[browser browser/browser browser/aliases browser/testing].each do |path|
    test "require #{path.inspect} still defines Browser, once deprecated" do
      output, errors, status = run_ruby(%(require "#{path}"), %(require "browser"),
        "print Browser.equal?(Agentry)")

      assert status.success?, errors
      assert_equal "true", output
      assert_equal 1, errors.scan("the Browser constant are deprecated").size
      assert_includes errors, Agentry::MIGRATION_GUIDE_URL
    end
  end

  test "the deprecation stays silent where Ruby hides deprecations" do
    _output, errors, status = Open3.capture3(RbConfig.ruby, "-W:no-deprecated", "-I", LIB_PATH,
      "-e", 'require "browser"')

    assert status.success?, errors
    assert_empty errors
  end
end
