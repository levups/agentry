# frozen_string_literal: true

require "test_helper"
require "browser/rails"
require "sample_app"

class RequestHeadersTest < Minitest::Test
  class SignalsController < ActionController::Base
    def show
      render plain: [browser.platform.version, browser.device.mobile?, browser.cloudflare.country].join(" ")
    end
  end

  HEADERS = {
    "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
                         "(KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "HTTP_ACCEPT" => "text/html",
    "HTTP_SEC_CH_UA_MOBILE" => "?0",
    "HTTP_SEC_CH_UA_PLATFORM" => '"Windows"',
    "HTTP_SEC_CH_UA_PLATFORM_VERSION" => '"19.0.0"',
    "HTTP_CF_IPCOUNTRY" => "FR"
  }.freeze

  test "the controller helper reads the client hints and the Cloudflare headers" do
    _status, _headers, body = SignalsController.action(:show).call(Rack::MockRequest.env_for("/", HEADERS))

    assert_equal "11 false FR", body.each.to_a.join
  end

  test "the middleware reads them too" do
    seen = nil
    middleware = Browser::Middleware.new(->(_env) { [200, {}, []] }) do
      seen = [browser.platform.windows11?, browser.cloudflare.country]
      nil
    end

    middleware.call(Rack::MockRequest.env_for("/", HEADERS))

    assert_equal [true, "FR"], seen
  end

  test "the middleware and the helper read headers that are not valid UTF-8" do
    headers = HEADERS.merge("HTTP_ACCEPT_LANGUAGE" => "fr-FR")
      .transform_values { |value| "#{value}\xFF".force_encoding(Encoding::UTF_8) }
    middleware = Browser::Middleware.new(->(_env) { [200, {}, []] }) do
      redirect_to "/upgrade" if browser.chrome? && browser.accept_language.first.code == "fr"
    end

    status, = middleware.call(Rack::MockRequest.env_for("/", headers))
    # Rails itself raises on such an Accept header.
    _status, _headers, body = SignalsController.action(:show)
      .call(Rack::MockRequest.env_for("/", headers.merge("HTTP_ACCEPT" => "text/html")))

    assert_equal 302, status
    assert_equal "10.0 false ", body.each.to_a.join
  end
end
