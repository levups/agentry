# frozen_string_literal: true

require "test_helper"

class CloudflareTest < Minitest::Test
  USER_AGENT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  teardown do
    Browser::Cloudflare.header_names = {}
  end

  def cloudflare(headers)
    Browser.new(USER_AGENT, headers:).cloudflare
  end

  test "reads the headers of the Transform Rule" do
    cloudflare = cloudflare(
      "HTTP_X_BOT_VERIFIED" => "true", "HTTP_X_BOT_CATEGORY" => "Search Engine Crawler",
      "HTTP_X_BOT_SCORE" => "1", "HTTP_CF_IPCOUNTRY" => "US"
    )

    assert cloudflare.verified_bot?
    assert_equal :search_engine_crawler, cloudflare.bot_category
    assert_equal 1, cloudflare.bot_score
    assert_equal "US", cloudflare.country
  end

  test "names the categories as bot.category does" do
    assert_equal :monitoring_and_analytics, cloudflare("HTTP_X_BOT_CATEGORY" => "Monitoring & Analytics").bot_category
    assert_equal :ai_crawler, cloudflare("HTTP_X_BOT_CATEGORY" => "AI Crawler").bot_category
  end

  test "answers nothing without the headers" do
    [Browser.new(USER_AGENT).cloudflare, cloudflare({})].each do |cloudflare|
      refute cloudflare.verified_bot?
      assert_nil cloudflare.bot_category
      assert_nil cloudflare.bot_score
      assert_nil cloudflare.country
    end
  end

  test "ignores malformed values" do
    cloudflare = cloudflare(
      "HTTP_X_BOT_VERIFIED" => "yes", "HTTP_X_BOT_CATEGORY" => " ",
      "HTTP_X_BOT_SCORE" => "high", "HTTP_CF_IPCOUNTRY" => "France"
    )

    refute cloudflare.verified_bot?
    assert_nil cloudflare.bot_category
    assert_nil cloudflare.bot_score
    assert_nil cloudflare.country
    assert_nil cloudflare("HTTP_X_BOT_SCORE" => "100").bot_score
  end

  test "ignores a value longer than Cloudflare ever sends" do
    assert_nil cloudflare("HTTP_X_BOT_CATEGORY" => "Search Engine Crawler #{"x" * 200}").bot_category
    refute cloudflare("HTTP_X_BOT_VERIFIED" => "true#{" " * 200}").verified_bot?
  end

  test "ignores a value that is not valid UTF-8" do
    invalid = ->(value) { "#{value}\xFF".force_encoding(Encoding::UTF_8) }
    cloudflare = cloudflare(
      "HTTP_X_BOT_VERIFIED" => invalid.call("true"), "HTTP_X_BOT_CATEGORY" => invalid.call("Search Engine Crawler"),
      "HTTP_X_BOT_SCORE" => invalid.call("1"), "HTTP_CF_IPCOUNTRY" => invalid.call("US")
    )

    refute cloudflare.verified_bot?
    assert_nil cloudflare.bot_category
    assert_nil cloudflare.bot_score
    assert_nil cloudflare.country
  end

  test "reads the header names a site chose" do
    Browser::Cloudflare.header_names = {verified_bot: "X-Edge-Good-Bot", bot_score: "X-Edge-Score"}

    cloudflare = cloudflare("HTTP_X_EDGE_GOOD_BOT" => "true", "HTTP_X_EDGE_SCORE" => "87", "HTTP_X_BOT_SCORE" => "2")

    assert cloudflare.verified_bot?
    assert_equal 87, cloudflare.bot_score
    assert_equal "X-Bot-Category", Browser::Cloudflare.header_names[:bot_category]
  end

  test "refuses an unknown signal" do
    assert_raises(ArgumentError) { Browser::Cloudflare.header_names = {bot_sore: "X-Score"} }
  end
end
