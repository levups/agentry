# frozen_string_literal: true

require "test_helper"

class CacheTest < Minitest::Test
  class CustomBrowser < Agentry::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  class CustomPlatform < Agentry::Platform::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  class CustomDevice < Agentry::Device::Base
    def id
      :custom
    end

    def match?
      ua.include?("Custom")
    end
  end

  setup do
    Agentry.cache_size = 1000
  end

  teardown do
    Agentry.cache_size = 1000
  end

  def cached_user_agents
    Agentry::Cache.instance_variable_get(:@detection_by_user_agent).keys
  end

  test "shares the detection of a user agent between its browsers" do
    first = Agentry.new(Agentry["CHROME"])
    second = Agentry.new(Agentry["CHROME"])

    refute_same first, second
    assert_same first.platform, second.platform
    assert_same first.device, second.device
    assert_same first.bot, second.bot
  end

  test "keeps the caller's user agent and accept language per browser" do
    user_agent = Agentry["CHROME"].dup
    browser = Agentry.new(user_agent, accept_language: "fr")
    other = Agentry.new(Agentry["CHROME"], accept_language: "en")

    assert_same user_agent, browser.ua
    assert_equal "fr", browser.accept_language.first.code
    assert_equal "en", other.accept_language.first.code
  end

  test "keys the cache on a frozen copy of the user agent" do
    user_agent = Agentry["CHROME"].dup
    Agentry.new(user_agent).platform
    user_agent.replace(Agentry["FIREFOX"])

    assert Agentry.new(Agentry["CHROME"]).chrome?
    assert Agentry.new(Agentry["CHROME"]).platform.mac?
    assert Agentry.new(user_agent).firefox?
  end

  test "detects again when cache_size is 0" do
    Agentry.cache_size = 0
    first = Agentry.new(Agentry["CHROME"])
    second = Agentry.new(Agentry["CHROME"])

    assert second.chrome?
    refute_same first.platform, second.platform
    assert_empty cached_user_agents
  end

  test "empties the cache when full" do
    Agentry.cache_size = 2
    %w[CHROME FIREFOX SAFARI].each { |key| Agentry.new(Agentry[key]) }

    assert_equal [Agentry["SAFARI"]], cached_user_agents
  end

  test "rejects a cache_size that is not a positive Integer or 0" do
    assert_raises(ArgumentError) { Agentry.cache_size = -1 }
    assert_raises(ArgumentError) { Agentry.cache_size = nil }
  end

  test "raises on an oversized user agent before caching it" do
    user_agent = "x" * Agentry.user_agent_size_limit
    Agentry::Cache.clear

    assert_raises(Agentry::Error) { Agentry.new(user_agent) }
    assert_empty cached_user_agents
  end

  test "raises on a cached user agent once the size limit is lowered" do
    Agentry.new(Agentry["CHROME"])
    limit = Agentry.user_agent_size_limit
    Agentry.user_agent_size_limit = 10

    assert_raises(Agentry::Error) { Agentry.new(Agentry["CHROME"]) }
  ensure
    Agentry.user_agent_size_limit = limit
  end

  test "detects again when a browser matcher is added" do
    refute_equal :custom, Agentry.new("Custom").id

    Agentry.matchers.unshift(CustomBrowser)
    assert_equal :custom, Agentry.new("Custom").id
  ensure
    Agentry.matchers.delete(CustomBrowser)
    assert_equal :unknown_browser, Agentry.new("Custom").id
  end

  test "detects again when a platform matcher is added" do
    refute_equal :custom, Agentry.new("Custom").platform.id

    Agentry::Platform.matchers.unshift(CustomPlatform)
    assert_equal :custom, Agentry.new("Custom").platform.id
  ensure
    Agentry::Platform.matchers.delete(CustomPlatform)
  end

  test "detects again when a device matcher is replaced" do
    refute_equal :custom, Agentry.new("Custom").device.id
    unknown_device = Agentry::Device.matchers.last

    Agentry::Device.matchers[-1] = CustomDevice
    assert_equal :custom, Agentry.new("Custom").device.id
  ensure
    Agentry::Device.matchers[-1] = unknown_device
  end

  test "answers again when a bot matcher is added" do
    browser = Agentry.new("cached-script")
    refute browser.bot?

    matcher = ->(ua, _browser) { ua.include?("cached-script") }
    Agentry::Bot.matchers << matcher
    assert browser.bot?
    assert Agentry.new("cached-script").bot?
    assert_equal "Generic Bot", Agentry.new("cached-script").bot.name
  ensure
    Agentry::Bot.matchers.delete(matcher)
  end

  test "names again when the bot list grows" do
    assert_equal "Generic Bot", Agentry.new("cachedbot/1.0").bot.name

    Agentry::Bot.bots["cachedbot"] = "Cached Bot"
    assert_equal "Cached Bot", Agentry.new("cachedbot/1.0").bot.name
  ensure
    Agentry::Bot.bots.delete("cachedbot")
  end

  test "answers again when a bot exception is added" do
    assert Agentry.new("cachedbot/1.0").bot?

    Agentry::Bot.bot_exceptions << "cachedbot"
    refute Agentry.new("cachedbot/1.0").bot?
  ensure
    Agentry::Bot.bot_exceptions.delete("cachedbot")
  end

  test "compares versions alike with the cache on and off" do
    chrome_user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " \
      "Chrome/142.0.0.0 Safari/537.36"
    long_version = "1#{".0" * 40}"
    answers = lambda do
      browser = Agentry.new(chrome_user_agent.sub("142.0.0.0", long_version))
      chrome = Agentry.new(chrome_user_agent)
      [chrome.chrome?(">= 10"), chrome.chrome?("< 10"), chrome.chrome?([">= 1", "< 1000"]), chrome.chrome?(Integer(chrome.version)),
        chrome.chrome?("not a version"), browser.chrome?("~> 1.0"), browser.chrome?(">= 2")]
    end
    cached = Array.new(2) { answers.call }
    kept_versions = %i[@requirement_by_version @gem_version_by_version]
      .flat_map { |name| Agentry::Cache.instance_variable_get(name).keys }
    assert_includes kept_versions, "142.0.0.0"
    refute_includes kept_versions, long_version
    Agentry.cache_size = 0

    assert_equal [[true, false, true, true, false, true, false]] * 3, cached + [answers.call]
  end

  test "parses an accept language once and hands out copies" do
    first = Agentry.new("", accept_language: "fr-FR,en;q=0.8").accept_language
    first.clear
    second = Agentry.new("", accept_language: "fr-FR,en;q=0.8").accept_language

    assert_equal %w[fr-FR en], second.map(&:full)
    assert_same second.first,
      Agentry.new("", accept_language: "fr-FR,en;q=0.8").accept_language.first
  end

  test "does not cache an accept language listing more languages than a browser sends" do
    header = Array.new(Agentry::Cache::MAX_LANGUAGES_PER_CACHED_HEADER + 1) { |index| "x#{index}" }.join(",")
    Agentry::Cache.clear

    languages = Agentry.new("", accept_language: header).accept_language

    assert_equal %w[x0 x1], languages.first(2).map(&:full)
    assert_empty Agentry::Cache.instance_variable_get(:@languages_by_header)
    Agentry.new("", accept_language: header.sub(/,x\d+\z/, "")).accept_language
    assert_equal 1, Agentry::Cache.instance_variable_get(:@languages_by_header).size
  end

  test "gives the same answers from concurrent threads" do
    user_agents = Agentry.user_agents.values
    answers = ->(browser) do
      [browser.id, browser.full_version, browser.bot?, browser.bot.name,
        browser.platform.id, browser.device.id, browser.device.mobile?]
    end
    Agentry.cache_size = 0
    expected = user_agents.map { |user_agent| answers.call(Agentry.new(user_agent)) }
    Agentry.cache_size = 50

    threads = Array.new(4) do
      Thread.new do
        Array.new(3) do
          user_agents.map { |user_agent| answers.call(Agentry.new(user_agent)) }
        end
      end
    end

    threads.each do |thread|
      thread.value.each { |actual| assert_equal expected, actual }
    end
  end

  test "skips a browser only when its match? could not be true" do
    corpus = File.foreach(Agentry.root.join("corpus/user_agents.txt"),
      chomp: true)
    user_agents = Agentry.user_agents.values + corpus.to_a

    Agentry::REQUIRED_PATTERN_BY_MATCHER.each do |matcher_class, pattern|
      user_agents.each do |user_agent|
        next if user_agent.bytesize >= Agentry.user_agent_size_limit
        next unless matcher_class.new(user_agent).match?

        assert_match pattern, user_agent, matcher_class.name
      end
    end
  end
end
