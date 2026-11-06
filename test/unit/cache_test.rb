# frozen_string_literal: true

require "test_helper"

class CacheTest < Minitest::Test
  class CustomBrowser < Browser::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  class CustomPlatform < Browser::Platform::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  class CustomDevice < Browser::Device::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  setup do
    Browser.cache_size = 1000
  end

  teardown do
    Browser.cache_size = 1000
  end

  def cached_user_agents
    Browser::Cache.instance_variable_get(:@detection_by_user_agent).keys
  end

  test "shares the detection of a user agent between its browsers" do
    first = Browser.new(Browser["CHROME"])
    second = Browser.new(Browser["CHROME"])

    refute_same first, second
    assert_same first.platform, second.platform
    assert_same first.device, second.device
    assert_same first.bot, second.bot
  end

  test "keeps the caller's user agent and accept language per browser" do
    user_agent = Browser["CHROME"].dup
    browser = Browser.new(user_agent, accept_language: "fr")
    other = Browser.new(Browser["CHROME"], accept_language: "en")

    assert_same user_agent, browser.ua
    assert_equal "fr", browser.accept_language.first.code
    assert_equal "en", other.accept_language.first.code
  end

  test "keys the cache on a frozen copy of the user agent" do
    user_agent = Browser["CHROME"].dup
    Browser.new(user_agent).platform
    user_agent.replace(Browser["FIREFOX"])

    assert Browser.new(Browser["CHROME"]).chrome?
    assert Browser.new(Browser["CHROME"]).platform.mac?
    assert Browser.new(user_agent).firefox?
  end

  test "detects again when cache_size is 0" do
    Browser.cache_size = 0
    first = Browser.new(Browser["CHROME"])
    second = Browser.new(Browser["CHROME"])

    assert second.chrome?
    refute_same first.platform, second.platform
    assert_empty cached_user_agents
  end

  test "empties the cache when full" do
    Browser.cache_size = 2
    %w[CHROME FIREFOX SAFARI].each { |key| Browser.new(Browser[key]) }

    assert_equal [Browser["SAFARI"]], cached_user_agents
  end

  test "rejects a cache_size that is not a positive Integer or 0" do
    assert_raises(ArgumentError) { Browser.cache_size = -1 }
    assert_raises(ArgumentError) { Browser.cache_size = nil }
  end

  test "raises on an oversized user agent before caching it" do
    user_agent = "x" * Browser.user_agent_size_limit
    Browser::Cache.clear

    assert_raises(Browser::Error) { Browser.new(user_agent) }
    assert_empty cached_user_agents
  end

  test "raises on a cached user agent once the size limit is lowered" do
    Browser.new(Browser["CHROME"])
    limit = Browser.user_agent_size_limit
    Browser.user_agent_size_limit = 10

    assert_raises(Browser::Error) { Browser.new(Browser["CHROME"]) }
  ensure
    Browser.user_agent_size_limit = limit
  end

  test "detects again when a browser matcher is added" do
    refute_equal :custom, Browser.new("Custom").id

    Browser.matchers.unshift(CustomBrowser)
    assert_equal :custom, Browser.new("Custom").id
  ensure
    Browser.matchers.delete(CustomBrowser)
    assert_equal :unknown_browser, Browser.new("Custom").id
  end

  test "detects again when a platform matcher is added" do
    refute_equal :custom, Browser.new("Custom").platform.id

    Browser::Platform.matchers.unshift(CustomPlatform)
    assert_equal :custom, Browser.new("Custom").platform.id
  ensure
    Browser::Platform.matchers.delete(CustomPlatform)
  end

  test "detects again when a device matcher is replaced" do
    refute_equal :custom, Browser.new("Custom").device.id
    unknown_device = Browser::Device.matchers.last

    Browser::Device.matchers[-1] = CustomDevice
    assert_equal :custom, Browser.new("Custom").device.id
  ensure
    Browser::Device.matchers[-1] = unknown_device
  end

  test "answers again when a bot matcher is added" do
    browser = Browser.new("cached-script")
    refute browser.bot?

    matcher = ->(ua, _browser) { ua.include?("cached-script") }
    Browser::Bot.matchers << matcher
    assert browser.bot?
    assert Browser.new("cached-script").bot?
    assert_equal "Generic Bot", Browser.new("cached-script").bot.name
  ensure
    Browser::Bot.matchers.delete(matcher)
  end

  test "names again when the bot list grows" do
    assert_equal "Generic Bot", Browser.new("cachedbot/1.0").bot.name

    Browser::Bot.bots["cachedbot"] = "Cached Bot"
    assert_equal "Cached Bot", Browser.new("cachedbot/1.0").bot.name
  ensure
    Browser::Bot.bots.delete("cachedbot")
  end

  test "answers again when a bot exception is added" do
    assert Browser.new("cachedbot/1.0").bot?

    Browser::Bot.bot_exceptions << "cachedbot"
    refute Browser.new("cachedbot/1.0").bot?
  ensure
    Browser::Bot.bot_exceptions.delete("cachedbot")
  end

  test "parses an accept language once and hands out copies" do
    first = Browser.new("", accept_language: "fr-FR,en;q=0.8").accept_language
    first.clear
    second = Browser.new("", accept_language: "fr-FR,en;q=0.8").accept_language

    assert_equal %w[fr-FR en], second.map(&:full)
    assert_same second.first,
      Browser.new("", accept_language: "fr-FR,en;q=0.8").accept_language.first
  end

  test "does not cache an accept language listing more languages than a browser sends" do
    header = Array.new(Browser::Cache::MAX_LANGUAGES_PER_CACHED_HEADER + 1) { |index| "x#{index}" }.join(",")
    Browser::Cache.clear

    languages = Browser.new("", accept_language: header).accept_language

    assert_equal %w[x0 x1], languages.first(2).map(&:full)
    assert_empty Browser::Cache.instance_variable_get(:@languages_by_header)
    Browser.new("", accept_language: header.sub(/,x\d+\z/, "")).accept_language
    assert_equal 1, Browser::Cache.instance_variable_get(:@languages_by_header).size
  end

  test "gives the same answers from concurrent threads" do
    user_agents = Browser.user_agents.values
    answers = ->(browser) do
      [browser.id, browser.full_version, browser.bot?, browser.bot.name,
        browser.platform.id, browser.device.id, browser.device.mobile?]
    end
    Browser.cache_size = 0
    expected = user_agents.map { |user_agent| answers.call(Browser.new(user_agent)) }
    Browser.cache_size = 50

    threads = Array.new(4) do
      Thread.new do
        Array.new(3) do
          user_agents.map { |user_agent| answers.call(Browser.new(user_agent)) }
        end
      end
    end

    threads.each do |thread|
      thread.value.each { |actual| assert_equal expected, actual }
    end
  end

  test "skips a browser only when its match? could not be true" do
    corpus = File.foreach(Browser.root.join("corpus/user_agents.txt"),
      chomp: true)
    user_agents = Browser.user_agents.values + corpus.to_a

    Browser::REQUIRED_PATTERN_BY_MATCHER.each do |matcher_class, pattern|
      user_agents.each do |user_agent|
        next if user_agent.bytesize >= Browser.user_agent_size_limit
        next unless matcher_class.new(user_agent).match?

        assert_match pattern, user_agent, matcher_class.name
      end
    end
  end
end
