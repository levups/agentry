# frozen_string_literal: true

require "test_helper"
require "agentry/rails"
require "sample_app"

class AgentryRailsTest < Minitest::Test
  CHROME_ENV = Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => Agentry["CHROME"], "HTTP_ACCEPT" => "text/html")

  class AgentryController < ActionController::Base
    def show
      render inline: "<%= agentry.name %>"
    end

    def legacy
      render plain: [browser.name, browser.equal?(agentry)].join(" ")
    end
  end

  def with_deprecations_shown
    shown = Warning[:deprecated]
    Warning[:deprecated] = true
    Agentry.instance_variable_set(:@deprecations, nil)
    yield
  ensure
    Warning[:deprecated] = shown
  end

  test "controllers and views call agentry" do
    _status, _headers, body = AgentryController.action(:show).call(CHROME_ENV)

    assert_equal "Chrome", body.each.to_a.join
  end

  test "the browser helper still answers, once deprecated" do
    body = nil
    _out, errors = capture_io do
      with_deprecations_shown do
        2.times { _status, _headers, body = AgentryController.action(:legacy).call(CHROME_ENV.dup) }
      end
    end

    assert_equal "Chrome true", body.each.to_a.join
    assert_equal 1, errors.scan("the browser helper is deprecated").size
  end

  test "a middleware block calls agentry, browser once deprecated" do
    seen = []
    middleware = Agentry::Middleware.new(->(_env) { [200, {}, []] }) do
      seen << [agentry.name, browser.equal?(agentry)]
      nil
    end
    _out, errors = capture_io do
      with_deprecations_shown { middleware.call(CHROME_ENV.dup) }
    end

    assert_equal [["Chrome", true]], seen
    assert_includes errors, "browser in an Agentry::Middleware block is deprecated"
  end

  test "config.browser still reaches config.agentry" do
    assert_same Rails.application.config.agentry, Rails.application.config.browser
  end
end
