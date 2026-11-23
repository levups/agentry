# frozen_string_literal: true

module Agentry
  # The detections of the last user agents, the parsed Accept-Language
  # headers and Client Hints, shared by the threads of a process. Reads take no lock: under the
  # GVL a Hash read is atomic, and a thread that misses detects again. Writes
  # do, for the Rubies without a GVL.
  module Cache
    # Far more than a browser sends. A longer list is parsed again each time: 2 KB of "a,a,a" makes a thousand
    # objects, and a thousand such headers would hold 100 MB.
    MAX_LANGUAGES_PER_CACHED_HEADER = 32
    # A browser names 3 brands: a forged Sec-CH-UA naming dozens is parsed each time, so that an entry stays small.
    MAX_BRANDS_PER_CACHED_HINTS = 8

    @mutex = Mutex.new
    @detection_by_user_agent = {}
    @languages_by_header = {}
    @client_hints_by_values = {}
    @client_hints_count = 0
    @generation = 0

    def self.cached_detection(ua)
      current_detection_by_user_agent[ua]
    end

    def self.detection(ua)
      return Detection.new(ua) if Agentry.cache_size.zero?

      cached_detection(ua) || @mutex.synchronize do
        ua = -ua
        store(@detection_by_user_agent, ua, Detection.new(ua))
      end
    end

    # A copy each time: callers may change the array they get.
    def self.accept_language(header)
      return AcceptLanguage.parse(header) if Agentry.cache_size.zero?

      languages = @languages_by_header[header]
      return languages.dup if languages

      languages = AcceptLanguage.parse(header)
      return languages if languages.size > MAX_LANGUAGES_PER_CACHED_HEADER

      @mutex.synchronize { store(@languages_by_header, -header, languages.freeze) }.dup
    end

    # Keyed by the hint headers, which a Chromium browser sends alike on
    # each request: ClientHints is frozen, so every request shares it.
    def self.client_hints(headers)
      values = ClientHints.header_values(headers)
      return ClientHints::NONE if values.all?(&:nil?)
      return ClientHints.new(headers) if Agentry.cache_size.zero?

      # One Hash level per header, each keyed by a String: an Array key would be hashed and compared in Ruby, where
      # another thread can change the Hash halfway through a read that takes no lock.
      client_hints = @client_hints_by_values.dig(*values)
      return client_hints if client_hints

      client_hints = ClientHints.new(headers)
      return client_hints if client_hints.brand_count > MAX_BRANDS_PER_CACHED_HINTS

      @mutex.synchronize do
        if @client_hints_count >= Agentry.cache_size
          @client_hints_by_values = {}
          @client_hints_count = 0
        end
        *headers, platform_version = values.map { |value| value && -value }
        headers.reduce(@client_hints_by_values) { |level, value| level[value] ||= {} }[platform_version] = client_hints
        @client_hints_count += 1
        client_hints
      end
    end

    # Bumped when a matcher list, the bot list or its exceptions change: the
    # matchers are public arrays that apps extend at runtime.
    def self.generation
      return @generation if lists_unchanged?

      @mutex.synchronize do
        @generation += 1
        @detection_by_user_agent.clear
        remember_lists
      end
      @generation
    end

    def self.clear
      @mutex.synchronize do
        @detection_by_user_agent.clear
        @languages_by_header.clear
        @client_hints_by_values = {}
        @client_hints_count = 0
      end
    end

    # The bot list holds hundreds of entries: compared by identity and size,
    # like Bot.keywords_pattern, not entry by entry on every request.
    def self.lists_unchanged?
      @browser_matchers == Agentry.matchers &&
        @platform_matchers == Platform.matchers &&
        @device_matchers == Device.matchers &&
        @bot_matchers == Bot.matchers &&
        @bot_exceptions == Bot.bot_exceptions &&
        @bots.equal?(Bot.bots) && @bots_size == Bot.bots.size
    end

    def self.remember_lists
      @browser_matchers = Agentry.matchers.dup
      @platform_matchers = Platform.matchers.dup
      @device_matchers = Device.matchers.dup
      @bot_matchers = Bot.matchers.dup
      @bot_exceptions = Bot.bot_exceptions.dup
      @bots = Bot.bots
      @bots_size = Bot.bots.size
    end

    def self.current_detection_by_user_agent
      generation
      @detection_by_user_agent
    end

    def self.store(value_by_key, key, value)
      value_by_key.clear if value_by_key.size >= Agentry.cache_size
      value_by_key[key] = value
    end

    private_class_method :lists_unchanged?, :remember_lists,
      :current_detection_by_user_agent, :store
  end
end
