# frozen_string_literal: true

require "test_helper"

class HostileHeadersTest < Minitest::Test
  MAC_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
               "Version/17.0 Safari/605.1.15"

  # What a log line or a forged header holds: UTF-8 with a byte that is not.
  def invalid_utf8(string)
    "#{string}\xFF".force_encoding(Encoding::UTF_8)
  end

  def cached_versions
    %i[@@all @@release].sum { |name| Gem::Version.class_variable_get(name).size }
  end

  setup do
    Browser.cache_size = 1000
  end

  test "reads a user agent that is not valid UTF-8" do
    browser = Browser.new(invalid_utf8(MAC_SAFARI))

    assert_equal "Safari", browser.name
    assert_equal "17", browser.version
    assert_equal "macOS", browser.platform.name
    refute browser.bot?
    assert browser.ua.valid_encoding?
    assert Browser.new(invalid_utf8("Googlebot/2.1 ")).bot?
  end

  test "Bot.why? reads a user agent that is not valid UTF-8" do
    assert_equal Browser::Bot::KnownBotsMatcher, Browser::Bot.why?(invalid_utf8("Googlebot/2.1 "))
  end

  test "reads an Accept-Language header that is not valid UTF-8" do
    languages = Browser.new(MAC_SAFARI, accept_language: invalid_utf8("fr-FR,en;q=0.5")).accept_language

    assert_equal %w[fr-FR en], languages.map(&:full)
  end

  test "keeps none of the versions a user agent or a client hint sends" do
    skip "RubyGems no longer caches every version" unless Gem::Version.class_variable_defined?(:@@release)

    ask = lambda do |index|
      browser = Browser.new(MAC_SAFARI.sub("10_15_7", "10_15_#{index}").sub("17.0", "17.#{index}"),
        headers: {"HTTP_SEC_CH_UA_PLATFORM" => '"macOS"', "HTTP_SEC_CH_UA_PLATFORM_VERSION" => %("15.#{index}.a")})
      [browser.safari?(">= 17"), browser.safari?("~> 17.0"), browser.platform.name, browser.platform.mac?("~> 15.0")]
    end
    ask.call(1)
    before = cached_versions

    answers = (2..21).map(&ask)

    assert_equal [[true, true, "macOS", true]], answers.uniq
    assert_equal before, cached_versions
  end

  test "compares versions as RubyGems does, prereleases included" do
    headers = {"HTTP_SEC_CH_UA_PLATFORM" => '"macOS"', "HTTP_SEC_CH_UA_PLATFORM_VERSION" => '"15.1.a"'}
    platform = Browser.new(MAC_SAFARI, headers:).platform

    assert platform.mac?("~> 15.0")
    assert platform.mac?("< 15.1")
    refute platform.mac?("~> 15.1")
    refute platform.mac?(">= 15.1")
  end
end
