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
    Agentry.instance_variable_set(:@deprecations, Set.new)
    yield
  ensure
    Warning[:deprecated] = shown
  end

  test "controllers and views call agentry" do
    _status, _headers, body = AgentryController.action(:show).call(CHROME_ENV.dup)

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

  test "config.browser still reaches config.agentry, once deprecated" do
    options = nil
    _out, errors = capture_io do
      with_deprecations_shown { 2.times { options = Rails.application.config.browser.to_h } }
    end

    assert_equal Rails.application.config.agentry.to_h, options
    assert_equal 1, errors.scan("config.browser is deprecated").size
  end

  test "a @browser set for the browser gem's helper still answers" do
    controller = AgentryController.new
    controller.instance_variable_set(:@browser, Agentry.new(Agentry["IPHONE"]))

    assert_predicate controller.send(:agentry).device, :iphone?
  end

  test "a deprecation hidden when it first fires prints once deprecations are shown" do
    shown = Warning[:deprecated]
    Agentry.instance_variable_set(:@deprecations, Set.new)
    Warning[:deprecated] = false
    Agentry.deprecate("alice is deprecated")
    _out, errors = capture_io do
      Warning[:deprecated] = true
      Agentry.deprecate("alice is deprecated")
    end

    assert_includes errors, "alice is deprecated"
  ensure
    Warning[:deprecated] = shown
  end
end
