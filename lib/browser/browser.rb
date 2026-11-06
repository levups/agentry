# frozen_string_literal: true

if Gem.loaded_specs.key?("browser")
  raise LoadError, "agentry replaces the browser gem, they can't be loaded together: " \
    "remove gem \"browser\" from the Gemfile (or whatever depends on it)"
end

require "json"
require "pathname"

require_relative "version"
require_relative "detect_version"
require_relative "accept_language"
require_relative "base"
require_relative "safari"
require_relative "chrome"
require_relative "internet_explorer"
require_relative "firefox"
require_relative "edge"
require_relative "opera"
require_relative "blackberry"
require_relative "unknown"
require_relative "phantom_js"
require_relative "uc_browser"
require_relative "nokia"
require_relative "micro_messenger"
require_relative "weibo"
require_relative "qq"
require_relative "alipay"
require_relative "electron"
require_relative "facebook"
require_relative "otter"
require_relative "instagram"
require_relative "yandex"
require_relative "sputnik"
require_relative "snapchat"
require_relative "duck_duck_go"
require_relative "samsung_browser"
require_relative "huawei_browser"
require_relative "miui_browser"
require_relative "maxthon"
require_relative "sougou_browser"
require_relative "google_search_app"
require_relative "epiphany"

require_relative "bot"
require_relative "bot/empty_user_agent_matcher"
require_relative "bot/keyword_matcher"
require_relative "bot/known_bots_matcher"
require_relative "bot/ip_ranges"

require_relative "middleware"
require_relative "platform"
require_relative "device"
require_relative "meta"
require_relative "client_hints"
require_relative "cloudflare"
require_relative "detection"
require_relative "cache"

module Browser
  EMPTY_STRING = ""

  Bot::DEFAULT_MATCHERS =
    [Bot::EmptyUserAgentMatcher, Bot::KnownBotsMatcher, Bot::KeywordMatcher]
      .freeze

  Error = Class.new(StandardError)

  def self.root
    @root ||= Pathname.new(File.expand_path("../..", __dir__))
  end

  # data/bots.json for "bots", written from bots.yml by script/build_data.rb: edit the YAML.
  def self.load_data(name)
    JSON.load_file(root.join("data", "#{name}.json"))
  end

  def self.eager_load!
    [self, Platform, Device, Bot].each(&:matchers)
    Meta.rules
    AcceptLanguage.languages
    Device::Samsung.names
    Bot.known_bots_trie
    [Bot.bot_exceptions, Bot.search_engines, Bot.category_by_keyword].each { |keywords| Bot.keywords_pattern(keywords) }
    Bot::IPRanges.ranges_by_owner
    nil
  end

  class << self
    attr_accessor :user_agent_size_limit, :accept_language_size_limit
    attr_reader :cache_size
  end

  self.user_agent_size_limit = 2048
  self.accept_language_size_limit = 2048

  def self.cache_size=(size)
    unless size.is_a?(Integer) && size >= 0
      raise ArgumentError, "cache_size must be an Integer >= 0, got #{size.inspect}"
    end

    @cache_size = size
    Cache.clear
  end

  self.cache_size = 1000

  # Hold the list of browser matchers.
  # Order is important.
  def self.matchers
    @matchers ||= [
      Nokia,
      UCBrowser,
      PhantomJS,
      BlackBerry,
      Opera,
      Edge,
      InternetExplorer,
      Firefox,
      Otter,
      Epiphany,
      Facebook,
      Instagram,
      Snapchat,
      Weibo,
      MicroMessenger, # must be placed before QQ
      QQ,
      Alipay,
      Electron,
      Yandex,
      Sputnik,
      DuckDuckGo,
      SamsungBrowser,
      HuaweiBrowser,
      MiuiBrowser,
      Maxthon,
      SougouBrowser,
      GoogleSearchApp,

      # Must be last
      Chrome,
      Safari,
      Unknown
    ]
  end

  # A pattern that every user agent a built-in browser matches also matches:
  # Browser.new skips, without building it, a browser whose pattern fails.
  REQUIRED_PATTERN_BY_MATCHER = {
    Nokia => /S40OviBrowser/,
    UCBrowser => /UCBrowser/,
    PhantomJS => /PhantomJS/,
    BlackBerry => /BlackBerry|BB10/,
    Opera => %r{Opera|OPR/},
    Edge => %r{Edg|Trident/8},
    InternetExplorer => %r{MSIE|Trident/},
    Firefox => /Firefox|FxiOS/,
    Otter => /Otter/,
    Epiphany => /Epiphany/,
    Facebook => /FBAV|FBAN/,
    Instagram => /Instagram/,
    Snapchat => /Snapchat/,
    Weibo => /__weibo__/i,
    MicroMessenger => /MicroMessenger/i,
    QQ => %r{QQ/|QQBrowser}i,
    Alipay => /AlipayClient/i,
    Electron => /Electron/,
    Yandex => /YaBrowser/,
    Sputnik => /SputnikBrowser/,
    DuckDuckGo => /DuckDuckGo/,
    SamsungBrowser => /SamsungBrowser/,
    HuaweiBrowser => /HuaweiBrowser/i,
    MiuiBrowser => /MiuiBrowser/,
    Maxthon => /Maxthon/i,
    SougouBrowser => /(?i:SogouMobileBrowser)|\bSE\b/,
    GoogleSearchApp => /GSA/
  }.compare_by_identity.freeze

  def self.new(user_agent, **)
    user_agent ||= EMPTY_STRING
    # Before the first regexp: an oversized user agent then costs nothing, and
    # a byte that is not UTF-8 (forged, or read from a log) would make it raise.
    Base.validate_size(:user_agent, user_agent.to_s)
    user_agent = user_agent.scrub unless user_agent.valid_encoding?
    browser_class = Cache.cached_detection(user_agent)&.browser_class
    return browser_class.new(user_agent, **) if browser_class

    browser = detect(user_agent, **)
    Cache.detection(user_agent).browser_class = browser.class
    browser
  end

  def self.detect(user_agent, **)
    matchers.each do |matcher_class|
      required_pattern = REQUIRED_PATTERN_BY_MATCHER[matcher_class]
      next if required_pattern && !required_pattern.match?(user_agent)

      matcher = matcher_class.new(user_agent, **)
      return matcher if matcher.match?
    end
  end
  private_class_method :detect
end
