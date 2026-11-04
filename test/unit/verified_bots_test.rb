# frozen_string_literal: true

require "test_helper"
require "resolv"

class VerifiedBotsTest < Minitest::Test
  IP_RANGES = Browser::Bot::IPRanges
  GOOGLEBOT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
  GPTBOT = "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; GPTBot/1.2; +https://openai.com/gptbot)"
  CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " \
           "Chrome/142.0.0.0 Safari/537.36"
  PREFIXES_BY_OWNER = {
    google: ["66.249.64.0/27", "66.249.64.32/27", "66.249.66.0/24", "2001:4860:4801:10::/64"],
    openai: ["132.196.86.0/24"]
  }.freeze

  class FakeDNS
    attr_accessor :timeouts

    def initialize(name_by_ip, addresses_by_name)
      @name_by_ip = name_by_ip
      @addresses_by_name = addresses_by_name
    end

    def getname(ip)
      @name_by_ip.fetch(ip) { raise Resolv::ResolvError, "no name for #{ip}" }
    end

    def getaddresses(name)
      @addresses_by_name.fetch(name, [])
    end
  end

  setup do
    @shipped_prefixes_by_owner = IP_RANGES.prefixes_by_owner
    IP_RANGES.load(PREFIXES_BY_OWNER)
  end

  teardown do
    IP_RANGES.load(@shipped_prefixes_by_owner)
  end

  def with_dns(name_by_ip, addresses_by_name)
    dns = FakeDNS.new(name_by_ip, addresses_by_name)
    original_open = Resolv::DNS.method(:open)
    Resolv::DNS.define_singleton_method(:open) { |&block| block.call(dns) }
    yield
  ensure
    Resolv::DNS.define_singleton_method(:open, original_open)
  end

  test "names the owner of a crawler that publishes its ranges" do
    assert_equal :google, Browser.new(GOOGLEBOT).bot.owner
    assert_equal :openai, Browser.new(GPTBOT).bot.owner
    assert_equal :bing, Browser.new(Browser["BINGBOT"]).bot.owner
    assert_nil Browser.new(Browser["YANDEX_DIRECT"]).bot.owner
    assert_nil Browser.new(CHROME).bot.owner
  end

  test "verifies a crawler coming from its owner's ranges" do
    bot = Browser.new(GOOGLEBOT).bot

    assert bot.verified?("66.249.66.1")
    assert bot.verified?("66.249.64.63")
    assert bot.verified?("2001:4860:4801:10::1")
    assert bot.verified?("::ffff:66.249.66.1")
    refute bot.verified?("66.249.65.1")
    refute bot.verified?("132.196.86.1")
    refute bot.verified?("2001:4860:4801:11::1")
  end

  test "never verifies a user agent without an owner" do
    refute Browser.new(CHROME).bot.verified?("66.249.66.1")
    refute Browser.new(Browser["YANDEX_DIRECT"]).bot.verified?("66.249.66.1")
  end

  test "answers false to an invalid IP instead of raising" do
    bot = Browser.new(GOOGLEBOT).bot

    [nil, "", "garbage", "66.249.66", "66.249.66.1, 10.0.0.1", "66.249.66.0/24", "::g", 42].each do |ip|
      refute bot.verified?(ip), "#{ip.inspect} verified"
    end
  end

  test "merges adjacent and overlapping prefixes" do
    IP_RANGES.load(google: ["10.0.0.0/25", "10.0.0.128/25", "10.0.0.64/26", "10.0.2.0/24"])
    starts, ends = IP_RANGES.ranges_by_owner.dig(:google, Socket::AF_INET)

    assert_equal [IPAddr.new("10.0.0.0").to_i, IPAddr.new("10.0.2.0").to_i], starts
    assert_equal [IPAddr.new("10.0.0.255").to_i, IPAddr.new("10.0.2.255").to_i], ends
    assert IP_RANGES.include?(:google, "10.0.0.200")
    refute IP_RANGES.include?(:google, "10.0.1.0")
  end

  test "reverse DNS stays off unless asked" do
    with_dns({"66.249.90.1" => "crawl-66-249-90-1.googlebot.com"},
      "crawl-66-249-90-1.googlebot.com" => [Resolv::IPv4.create("66.249.90.1")]) do
      bot = Browser.new(GOOGLEBOT).bot

      refute bot.verified?("66.249.90.1")
      assert bot.verified?("66.249.90.1", reverse_dns: true)
    end
  end

  test "reverse DNS needs the owner's domain and a forward lookup back to the IP" do
    with_dns({"66.249.90.1" => "crawl.googlebot.com.example.org", "66.249.90.2" => "crawl.googlebot.com"},
      "crawl.googlebot.com" => [Resolv::IPv4.create("66.249.90.3")]) do
      bot = Browser.new(GOOGLEBOT).bot

      refute bot.verified?("66.249.90.1", reverse_dns: true)
      refute bot.verified?("66.249.90.2", reverse_dns: true)
      refute bot.verified?("66.249.90.4", reverse_dns: true)
    end
  end

  test "reverse DNS is not tried for owners that document none" do
    with_dns({"132.196.87.1" => "anything.openai.com"}, "anything.openai.com" => [Resolv::IPv4.create("132.196.87.1")]) do
      refute Browser.new(GPTBOT).bot.verified?("132.196.87.1", reverse_dns: true)
    end
  end

  test "ships ranges for every owner" do
    IP_RANGES.load(@shipped_prefixes_by_owner)

    assert_equal IP_RANGES::SOURCES.keys.sort, IP_RANGES.prefixes_by_owner.keys.sort
    IP_RANGES.prefixes_by_owner.each do |owner, prefixes|
      refute_empty prefixes, owner
      assert_equal prefixes.uniq.size, prefixes.size, owner
    end
    assert_includes Browser.root.join("browserx.gemspec").read, "*.yml"
  end

  test "load swaps the ranges at runtime" do
    IP_RANGES.load(google: ["192.0.2.0/24"])

    assert Browser.new(GOOGLEBOT).bot.verified?("192.0.2.1")
    refute Browser.new(GOOGLEBOT).bot.verified?("66.249.66.1")
  end

  test "refresh keeps the current ranges when a source fails" do
    original_fetch = IP_RANGES.method(:fetch)
    IP_RANGES.define_singleton_method(:fetch) { raise Browser::Error, "https://example.org: HTTP 503" }

    assert_raises(Browser::Error) { IP_RANGES.refresh }
    assert Browser.new(GOOGLEBOT).bot.verified?("66.249.66.1")
  ensure
    IP_RANGES.define_singleton_method(:fetch, original_fetch)
  end
end
