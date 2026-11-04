# frozen_string_literal: true

require "test_helper"

class BotCategoriesTest < Minitest::Test
  # Captured from the drivers on 2026-11-04: playwright-ruby-client 1.64.0 (what
  # capybara-playwright-driver runs) and selenium-webdriver 4.32.0, headless,
  # plus the Linux form CI runners send.
  SYSTEM_TEST_USER_AGENTS = {
    "Playwright Chromium" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                             "(KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36",
    "Playwright Chromium on Linux" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " \
                                      "(KHTML, like Gecko) HeadlessChrome/156.0.8078.4 Safari/537.36",
    "Playwright WebKit" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
                           "(KHTML, like Gecko) Version/27.2 Safari/605.1.15",
    "Selenium Chrome" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                         "(KHTML, like Gecko) HeadlessChrome/157.0.0.0 Safari/537.36",
    "Selenium Firefox" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:159.0) Gecko/20100101 Firefox/159.0"
  }.freeze

  SYSTEM_TEST_USER_AGENTS.each do |driver, user_agent|
    test "the system tests of #{driver} are not bots" do
      refute Browser.new(user_agent).bot?
    end
  end

  test "headless Chrome is a test driver, not a bot" do
    bot = Browser.new(SYSTEM_TEST_USER_AGENTS.fetch("Playwright Chromium")).bot

    assert_equal :browser_automation, bot.category
    assert_nil bot.name
    refute bot.ai?
  end

  test "a browser has no category" do
    bot = Browser.new(Browser["CHROME"]).bot

    assert_nil bot.category
    refute bot.ai?
    refute bot.user_triggered?
  end

  test "a bot exception has no category" do
    assert_nil Browser.new("Pinterest/Android").bot.category
  end

  test "a bot caught by a keyword alone has no category" do
    assert_nil Browser.new("some-bot").bot.category
  end

  {
    "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; ChatGPT-User/1.0; +https://openai.com/bot)" =>
      [:ai_assistant, "ChatGPT"],
    "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Claude-User/1.0; +Claude-User@anthropic.com)" =>
      [:ai_assistant, "Claude-User"],
    "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; Perplexity-User/1.0; " \
    "+https://perplexity.ai/perplexity-user)" => [:ai_assistant, "Perplexity-User"],
    "meta-externalagent/1.1 (+https://developers.facebook.com/docs/sharing/webmasters/crawler)" =>
      [:ai_crawler, "Meta-ExternalAgent"],
    "Mozilla/5.0 (compatible; Google-Ads-Conversions)" => [:advertising_and_marketing, "Google-Ads-Conversions"],
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" =>
      [:search_engine_crawler, "Google Bot"],
    "curl/8.7.1" => [:http_library, "curl unix CLI http client"],
    "python-requests/2.32.3" => [:http_library, "Python http library"],
    "got/14.4.5 (https://github.com/sindresorhus/got)" => [:http_library, "sindresorhus/got"],
    "sqlmap/1.8.11#stable (https://sqlmap.org)" => [:scanner, "sqlmap"],
    "Mozilla/5.00 (Nikto/2.5.0) (Evasions:None) (Test:Port Check)" => [:scanner, "Nikto"],
    "Mozilla/5.0 (compatible; CensysInspect/1.1; +https://about.censys.io/)" => [:scanner, "CensysInspect"]
  }.each do |user_agent, (category, name)|
    test "#{name} is a bot of category #{category}" do
      bot = Browser.new(user_agent).bot

      assert bot.bot?
      assert_equal name, bot.name
      assert_equal category, bot.category
    end
  end

  test "AI agents acting for a person are user-triggered" do
    bot = Browser.new("Mozilla/5.0 (compatible; Claude-User/1.0)").bot

    assert bot.ai?
    assert bot.user_triggered?
  end

  test "AI crawlers are not user-triggered" do
    bot = Browser.new("Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)").bot

    assert bot.ai?
    refute bot.user_triggered?
  end

  test "a search engine is not AI" do
    refute Browser.new(Browser["GOOGLE_BOT"]).bot.ai?
  end

  test "every bots.yml keyword has at most one category" do
    keywords = Browser::Bot.load_yaml("bot_categories.yml").values.flatten

    assert_equal keywords.uniq, keywords
  end

  test "extends the categories in runtime" do
    Browser::Bot.bots["faraday"] = "Faraday"
    Browser::Bot.category_by_keyword["faraday"] = :http_library

    assert_equal :http_library, Browser.new("Faraday v2.12.0").bot.category
  ensure
    Browser::Bot.bots.delete("faraday")
    Browser::Bot.category_by_keyword.delete("faraday")
  end
end
