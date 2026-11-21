# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  skip %r{/test/}
end

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "logger"
require "minitest/autorun"
require "minitest/utils"
require "agentry"
require "agentry/testing"
require "browser" # upstream's tests, unmodified, call Browser
require "yaml"

module Minitest
  class Test
    setup do
      Agentry::Bot.instance_variable_set(:@detect_empty_ua, false)
    end

    def assert_deprecated(message, file, line, &block)
      message = "#{message} (called from #{file}:#{line})"
      _out, err = capture_io(&block)
      assert_includes err, message
    end
  end
end

# Override Agentry::Base#warn, so we don't output deprecation messages.
module Agentry
  class Base
    def warn(*)
    end
  end
end
