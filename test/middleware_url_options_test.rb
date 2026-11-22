# frozen_string_literal: true

require "test_helper"
require "browser/rails"
require "sample_app"

class MiddlewareUrlOptionsTest < Minitest::Test
  def teardown
    Rails.configuration.browser.default_url_options = nil
  end

  test "builds urls from config.browser.default_url_options" do
    Rails.configuration.browser.default_url_options = {host: "example.com"}

    assert_equal "http://example.com/upgrade", context.upgrade_url
  end

  test "builds paths without default_url_options or action mailer" do
    assert_equal "/upgrade", context.upgrade_path
  end

  private def context
    Browser::Middleware::Context.new(
      ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))
    )
  end
end
