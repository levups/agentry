# frozen_string_literal: true

require "test_helper"
require "open3"

class GemConflictTest < Minitest::Test
  test "refuses to load next to the browser gem" do
    lib_path = File.expand_path("../../lib", __dir__)
    activate_browser_gem =
      'Gem.loaded_specs["browser"] = Gem::Specification.new("browser", "6.2.0")'
    _output, errors, status = Open3.capture3(RbConfig.ruby, "-I", lib_path,
      "-e", activate_browser_gem, "-e", 'require "browserx"')

    refute status.success?
    assert_includes errors, "browserx replaces the browser gem"
  end
end
