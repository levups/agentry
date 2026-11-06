# frozen_string_literal: true

require "test_helper"
require "net/http"
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
    attr_reader :queries

    def initialize(name_by_ip, addresses_by_name)
      @name_by_ip = name_by_ip
      @addresses_by_name = addresses_by_name
      @queries = []
    end

    def getname(ip)
      @queries << ip
      @name_by_ip.fetch(ip) { raise Resolv::ResolvError, "no name for #{ip}" }
    end

    # An absolute name, so that the resolver's search list never applies.
    def getaddresses(name)
      raise ArgumentError, "#{name} is not absolute" unless name.absolute?

      @queries << name.to_s
      @addresses_by_name.fetch(name.to_s, [])
    end
  end

  setup do
    @shipped_prefixes_by_owner = IP_RANGES.prefixes_by_owner
    IP_RANGES.load(PREFIXES_BY_OWNER)
  end

  teardown do
    IP_RANGES.load(@shipped_prefixes_by_owner)
    IP_RANGES.dns_timeout = IP_RANGES::DNS_TIMEOUT_SECONDS
    IP_RANGES.dns_cache_size = 0
    IP_RANGES.dns_cache_ttl = 3600
  end

  def with_dns(name_by_ip, addresses_by_name)
    dns = FakeDNS.new(name_by_ip, addresses_by_name)
    original_open = Resolv::DNS.method(:open)
    Resolv::DNS.define_singleton_method(:open) { |&block| block.call(dns) }
    yield dns
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

  test "reverse DNS refuses a Google Cloud VM's googleusercontent.com name" do
    with_dns({"34.1.2.3" => "3.2.1.34.bc.googleusercontent.com"},
      "3.2.1.34.bc.googleusercontent.com" => [Resolv::IPv4.create("34.1.2.3")]) do
      refute Browser.new(GOOGLEBOT).bot.verified?("34.1.2.3", reverse_dns: true)
    end
  end

  GOOGLE_NAME_BY_IP = {"66.249.90.1" => "crawl-66-249-90-1.googlebot.com", "203.0.113.1" => "evil.example.com"}.freeze
  GOOGLE_ADDRESSES_BY_NAME = {"crawl-66-249-90-1.googlebot.com" => [Resolv::IPv4.create("66.249.90.1")]}.freeze

  test "reverse DNS asks the DNS on every call unless a cache is set" do
    with_dns(GOOGLE_NAME_BY_IP, GOOGLE_ADDRESSES_BY_NAME) do |dns|
      bot = Browser.new(GOOGLEBOT).bot
      2.times { assert bot.verified?("66.249.90.1", reverse_dns: true) }

      assert_equal 4, dns.queries.size
      assert_equal IP_RANGES::DNS_TIMEOUT_SECONDS, dns.timeouts
    end
  end

  test "reverse DNS remembers verdicts, forged ones included, when asked to" do
    IP_RANGES.dns_cache_size = 10
    with_dns(GOOGLE_NAME_BY_IP, GOOGLE_ADDRESSES_BY_NAME) do |dns|
      bot = Browser.new(GOOGLEBOT).bot
      2.times do
        assert bot.verified?("66.249.90.1", reverse_dns: true)
        refute bot.verified?("203.0.113.1", reverse_dns: true)
        refute bot.verified?("203.0.113.2", reverse_dns: true)
      end

      assert_equal ["66.249.90.1", "crawl-66-249-90-1.googlebot.com", "203.0.113.1", "203.0.113.2"], dns.queries
    end
  end

  test "reverse DNS forgets the oldest verdict when the cache is full" do
    IP_RANGES.dns_cache_size = 1
    with_dns(GOOGLE_NAME_BY_IP, GOOGLE_ADDRESSES_BY_NAME) do |dns|
      bot = Browser.new(GOOGLEBOT).bot
      %w[203.0.113.1 203.0.113.2 203.0.113.2 203.0.113.1].each { |ip| refute bot.verified?(ip, reverse_dns: true) }

      assert_equal %w[203.0.113.1 203.0.113.2 203.0.113.1], dns.queries
    end
  end

  test "reverse DNS asks again once a verdict expires" do
    IP_RANGES.dns_cache_size = 10
    IP_RANGES.dns_cache_ttl = 0.01
    with_dns(GOOGLE_NAME_BY_IP, GOOGLE_ADDRESSES_BY_NAME) do |dns|
      bot = Browser.new(GOOGLEBOT).bot
      refute bot.verified?("203.0.113.1", reverse_dns: true)
      sleep 0.02
      refute bot.verified?("203.0.113.1", reverse_dns: true)

      assert_equal %w[203.0.113.1 203.0.113.1], dns.queries
    end
  end

  test "reverse DNS takes the timeout given" do
    IP_RANGES.dns_timeout = 0.25
    with_dns(GOOGLE_NAME_BY_IP, GOOGLE_ADDRESSES_BY_NAME) do |dns|
      Browser.new(GOOGLEBOT).bot.verified?("203.0.113.1", reverse_dns: true)

      assert_in_delta 0.25, dns.timeouts
    end
  end

  test "refuses invalid DNS settings" do
    [0, -1, "1", nil].each do |value|
      assert_raises(ArgumentError) { IP_RANGES.dns_timeout = value }
      assert_raises(ArgumentError) { IP_RANGES.dns_cache_ttl = value }
    end
    [-1, 1.5, "10", nil].each { |value| assert_raises(ArgumentError) { IP_RANGES.dns_cache_size = value } }
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
  end

  test "load swaps the ranges at runtime" do
    IP_RANGES.load(google: ["192.0.2.0/24"])

    assert Browser.new(GOOGLEBOT).bot.verified?("192.0.2.1")
    refute Browser.new(GOOGLEBOT).bot.verified?("66.249.66.1")
  end

  def with_responses(responses)
    requested = []
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) do |host, *, **, &block|
      http = Object.new
      http.define_singleton_method(:get) do |path, _headers|
        requested << "#{host}#{path}"
        responses.shift
      end
      block.call(http)
    end
    yield requested
  ensure
    Net::HTTP.define_singleton_method(:start, original_start)
  end

  def response(status, body: nil, location: nil)
    klass = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s)
    klass.new("1.1", status.to_s, "").tap do |response|
      response["Location"] = location if location
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  def fetch_prefixes(url)
    IP_RANGES.send(:fetch_prefixes, url)
  end

  test "fetch follows a redirect on the owner's host" do
    body = JSON.generate(prefixes: [{ipv4Prefix: "66.249.64.0/27"}, {ipv6Prefix: "2001:4860:4801:10::/64"}])
    with_responses([response(301, location: "/new.json"), response(200, body:)]) do |requested|
      assert_equal ["66.249.64.0/27", "2001:4860:4801:10::/64"], fetch_prefixes("https://example.com/old.json")
      assert_equal ["example.com/old.json", "example.com/new.json"], requested
    end
  end

  test "fetch refuses a redirect to another host or to plain HTTP" do
    ["https://example.org/ranges.json", "http://example.com/ranges.json", nil].each do |location|
      with_responses([response(302, location:)]) do
        assert_raises(Browser::Error) { fetch_prefixes("https://example.com/ranges.json") }
      end
    end
  end

  test "fetch refuses a malformed document" do
    ["[]", "{}", '{"prefixes": []}', '{"prefixes": ["66.249.64.0/27"]}', '{"prefixes": [{"ipv4Prefix": 1}]}',
      "not json"].each do |body|
      with_responses([response(200, body:)]) do
        assert_raises(Browser::Error, body) { fetch_prefixes("https://example.com/ranges.json") }
      end
    end
  end

  test "fetch refuses a prefix no crawler could own" do
    original_fetch_prefixes = IP_RANGES.method(:fetch_prefixes)
    %w[0.0.0.0/0 8.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16 224.0.0.0/4 ::/0 2001::/16 fc00::/7 fe80::/10
      ff02::/16].each do |prefix|
      IP_RANGES.define_singleton_method(:fetch_prefixes) { |_url| ["66.249.64.0/27", prefix] }

      assert_raises(Browser::Error, prefix) { IP_RANGES.fetch }
    end
  ensure
    IP_RANGES.define_singleton_method(:fetch_prefixes, original_fetch_prefixes)
    IP_RANGES.singleton_class.send(:private, :fetch_prefixes)
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
