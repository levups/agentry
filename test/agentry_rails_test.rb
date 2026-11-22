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
    printed = Agentry.instance_variable_get(:@deprecations)
    Warning[:deprecated] = true
    Agentry.instance_variable_set(:@deprecations, Set.new)
    yield
  ensure
    Warning[:deprecated] = shown
    Agentry.instance_variable_set(:@deprecations, printed)
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

  test "the browser helper honours a @browser set for the browser gem, agentry does not" do
    controller = AgentryController.new
    controller.set_request!(ActionDispatch::Request.new(CHROME_ENV.dup))
    controller.instance_variable_set(:@browser, Agentry.new(Agentry["IPHONE"]))

    capture_io do
      assert_predicate controller.send(:browser).device, :iphone?
    end
    assert_equal "Chrome", controller.send(:agentry).name
  end

  test "browser in a middleware block honours a @browser the block set, as browser did" do
    seen = []
    middleware = Agentry::Middleware.new(->(_env) { [200, {}, []] }) do
      @browser = Agentry.new(Agentry["IPHONE"])
      seen << [browser.device.iphone?, agentry.name]
      nil
    end
    capture_io { middleware.call(CHROME_ENV.dup) }

    assert_equal [[true, "Chrome"]], seen
  end

  test "a middleware block calls agentry, browser once deprecated" do
    seen = []
    middleware = Agentry::Middleware.new(->(_env) { [200, {}, []] }) do
      seen << [agentry.name, browser.equal?(agentry), @browser.equal?(agentry)]
      nil
    end
    _out, errors = capture_io do
      with_deprecations_shown { middleware.call(CHROME_ENV.dup) }
    end

    assert_equal [["Chrome", true, true]], seen
    assert_includes errors, "browser in an Agentry::Middleware block is deprecated"
  end

  test "config.browser still reaches config.agentry, once deprecated" do
    agentry_config = Rails.application.config.agentry
    _out, errors = capture_io do
      with_deprecations_shown { 2.times { Rails.application.config.browser.alice = "bob" } }
    end

    assert_equal "bob", agentry_config.alice
    assert_equal 1, errors.scan("config.browser is deprecated").size
  ensure
    agentry_config.delete(:alice)
  end

  test "a config.browser the app reassigned becomes config.agentry, once deprecated" do
    config = ActiveSupport::OrderedOptions.new
    config.agentry = ActiveSupport::OrderedOptions.new
    config.browser = ActiveSupport::OrderedOptions.new
    config.browser.default_url_options = {host: "alice.example.com"}
    _out, errors = capture_io do
      with_deprecations_shown { Agentry::Railtie.adopt_reassigned_browser_config(config) }
    end

    assert_equal({host: "alice.example.com"}, config.agentry.default_url_options)
    assert_includes errors, "config.browser is deprecated"
  end

  test "a deprecation hidden when it first fires prints once deprecations are shown" do
    with_deprecations_shown do
      Warning[:deprecated] = false
      Agentry.deprecate("alice is deprecated")
      _out, errors = capture_io do
        Warning[:deprecated] = true
        Agentry.deprecate("alice is deprecated")
      end

      assert_includes errors, "alice is deprecated"
    end
  end
end
