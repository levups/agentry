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
    Agentry.cache_size = 1000
  end

  test "reads a user agent that is not valid UTF-8" do
    browser = Agentry.new(invalid_utf8(MAC_SAFARI))

    assert_equal "Safari", browser.name
    assert_equal "17", browser.version
    assert_equal "macOS", browser.platform.name
    refute browser.bot?
    assert browser.ua.valid_encoding?
    assert Agentry.new(invalid_utf8("Googlebot/2.1 ")).bot?
  end

  test "Bot.why? reads a user agent that is not valid UTF-8" do
    assert_equal Agentry::Bot::KnownBotsMatcher, Agentry::Bot.why?(invalid_utf8("Googlebot/2.1 "))
  end

  test "reads an Accept-Language header that is not valid UTF-8" do
    languages = Agentry.new(MAC_SAFARI, accept_language: invalid_utf8("fr-FR,en;q=0.5")).accept_language

    assert_equal %w[fr-FR en], languages.map(&:full)
  end

  test "keeps none of the versions a user agent or a client hint sends" do
    skip "RubyGems no longer caches every version" unless Gem::Version.class_variable_defined?(:@@release)

    ask = lambda do |index|
      browser = Agentry.new(MAC_SAFARI.sub("10_15_7", "10_15_#{index}").sub("17.0", "17.#{index}"),
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
    platform = Agentry.new(MAC_SAFARI, headers:).platform

    assert platform.mac?("~> 15.0")
    assert platform.mac?("< 15.1")
    refute platform.mac?("~> 15.1")
    refute platform.mac?(">= 15.1")
  end

  test "answers false to a version requirement RubyGems cannot compare" do
    browser = Agentry.new(MAC_SAFARI)

    refute browser.safari?("!")
    refute browser.platform.mac?("!")
    refute browser.safari?("not a version")
    assert browser.safari?(">= 1".encode("UTF-16LE"))
    assert browser.safari?([">= 1".encode("UTF-32BE")])
    refute browser.safari?(">= 100".encode("UTF-16LE"))
    refute browser.safari?(">= 1\xFF".dup.force_encoding("UTF-16LE"))
    assert browser.safari?([">= 1", "< 100"])
    assert browser.safari?(Gem::Requirement.new(">= 1", "< 100"))
    assert browser.safari?(17)
  end

  test "answers false to a requirement that holds itself, and reads a deeply nested one" do
    browser = Agentry.new(MAC_SAFARI)
    itself = [">= 1"]
    itself << itself
    deep = ">= 1"
    100_000.times { deep = [deep] }

    refute browser.safari?(itself)
    assert browser.safari?(deep)
  end

  test "checks a version on a frozen browser" do
    browser = Agentry.new(MAC_SAFARI).freeze

    assert browser.safari?(">= 1")
  end
end
