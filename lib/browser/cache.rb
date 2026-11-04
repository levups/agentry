# frozen_string_literal: true

module Browser
  # The detections of the last user agents and the parsed Accept-Language
  # headers, shared by the threads of a process. Reads take no lock: under the
  # GVL a Hash read is atomic, and a thread that misses detects again. Writes
  # do, for the Rubies without a GVL.
  module Cache
    @mutex = Mutex.new
    @detection_by_user_agent = {}
    @languages_by_header = {}
    @generation = 0

    def self.cached_detection(ua)
      current_detection_by_user_agent[ua]
    end

    def self.detection(ua)
      return Detection.new(ua) if Browser.cache_size.zero?

      cached_detection(ua) || @mutex.synchronize do
        ua = -ua
        store(@detection_by_user_agent, ua, Detection.new(ua))
      end
    end

    # A copy each time: callers may change the array they get.
    def self.accept_language(header)
      return AcceptLanguage.parse(header) if Browser.cache_size.zero?

      languages = @languages_by_header[header] || @mutex.synchronize do
        store(@languages_by_header, -header,
          AcceptLanguage.parse(header).freeze)
      end
      languages.dup
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
      end
    end

    # The bot list holds hundreds of entries: compared by identity and size,
    # like Bot.keywords_pattern, not entry by entry on every request.
    def self.lists_unchanged?
      @browser_matchers == Browser.matchers &&
        @platform_matchers == Platform.matchers &&
        @device_matchers == Device.matchers &&
        @bot_matchers == Bot.matchers &&
        @bot_exceptions == Bot.bot_exceptions &&
        @bots.equal?(Bot.bots) && @bots_size == Bot.bots.size
    end

    def self.remember_lists
      @browser_matchers = Browser.matchers.dup
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
      value_by_key.clear if value_by_key.size >= Browser.cache_size
      value_by_key[key] = value
    end

    private_class_method :lists_unchanged?, :remember_lists,
      :current_detection_by_user_agent, :store
  end
end
