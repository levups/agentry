# frozen_string_literal: true

module Agentry
  # The detections of the last user agents and the parsed Accept-Language
  # headers, shared by the threads of a process. Reads take no lock: under the
  # GVL a Hash read is atomic, and a thread that misses detects again. Writes
  # do, for the Rubies without a GVL.
  module Cache
    # Far more than a browser sends. A longer list is parsed again each time: 2 KB of "a,a,a" makes a thousand
    # objects, and a thousand such headers would hold 100 MB.
    MAX_LANGUAGES_PER_CACHED_HEADER = 32

    # The public lists apps change at runtime (the matchers, the bot exceptions): each change counts, so that checking
    # them costs an integer comparison on every request instead of comparing every entry.
    class List < Array
      # Every Array method that changes its receiver: CacheTest fails when a new Ruby adds one.
      MUTATORS = %i[
        << []= append clear collect! compact! concat delete delete_at delete_if fill filter! flatten! insert keep_if
        map! pop prepend push reject! replace reverse! rotate! select! shift shuffle! slice! sort! sort_by! uniq!
        unshift
      ].freeze

      MUTATORS.each do |name|
        # Counted even when a block breaks out halfway, the list changed already.
        define_method(name) do |*arguments, **options, &block|
          super(*arguments, **options, &block)
        ensure
          Cache.list_changed
        end
      end
    end

    @mutex = Mutex.new
    @detection_by_user_agent = {}
    @languages_by_header = {}
    @generation = 0
    @list_changes = 0
    @seen_list_changes = 0

    def self.cached_detection(ua)
      generation
      @detection_by_user_agent[ua]
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

    # Moves when a List changes, when a list is replaced by another object (a
    # stub, a reset), or when the bot list grows, shrinks or is replaced: a Hash
    # keyed by keyword, compared by identity and size like Bot.keywords_pattern.
    def self.generation
      bots = Bot.bots
      return @generation if @list_changes == @seen_list_changes && bots.equal?(@bots) && bots.size == @bots_size &&
        lists_in_place?

      changed
    end

    # Without a lock: an app may change a list from a signal handler, where Ruby refuses one.
    def self.list_changed
      @list_changes += 1
    end

    def self.changed
      @mutex.synchronize do
        # Emptied before the lists are recorded as seen: a reader in between still finds them changed.
        list_changes = @list_changes
        @detection_by_user_agent.clear
        generation = @generation += 1
        @seen_list_changes = list_changes
        @bots = Bot.bots
        @bots_size = @bots.size
        @browser_matchers = remembered(Agentry.matchers)
        @platform_matchers = remembered(Platform.matchers)
        @device_matchers = remembered(Device.matchers)
        @bot_matchers = remembered(Bot.matchers)
        @bot_exceptions = remembered(Bot.bot_exceptions)
        generation
      end
    end

    def self.lists_in_place?
      in_place?(Agentry.matchers, @browser_matchers) && in_place?(Platform.matchers, @platform_matchers) &&
        in_place?(Device.matchers, @device_matchers) && in_place?(Bot.matchers, @bot_matchers) &&
        in_place?(Bot.bot_exceptions, @bot_exceptions)
    end

    # A List counts its changes; any other Array put in its place is compared entry by entry.
    def self.remembered(list)
      list.instance_of?(List) ? list : list.dup.freeze
    end

    def self.in_place?(list, remembered)
      list.instance_of?(List) ? list.equal?(remembered) : list == remembered
    end

    def self.clear
      @mutex.synchronize do
        @detection_by_user_agent.clear
        @languages_by_header.clear
      end
    end

    def self.store(value_by_key, key, value)
      value_by_key.clear if value_by_key.size >= Agentry.cache_size
      value_by_key[key] = value
    end

    private_class_method :changed, :lists_in_place?, :remembered, :in_place?, :store
  end
end
