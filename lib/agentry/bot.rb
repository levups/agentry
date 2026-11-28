# frozen_string_literal: true

module Agentry
  class Bot
    GENERIC_NAME = "Generic Bot"
    AI_CATEGORIES = %i[ai_agent ai_assistant ai_crawler ai_search].freeze
    USER_TRIGGERED_CATEGORIES = %i[ai_agent ai_assistant].freeze
    # The shortest bots.yml keyword: a shorter one an app adds shortens the prefixes.
    MAX_PREFIX_BYTES = 4

    def self.matchers
      @matchers ||= default_matchers
    end

    def self.default_matchers
      DEFAULT_MATCHERS.dup
    end

    # browser's API. The gem ships its lists as JSON only: load_yaml("bots.yml")
    # reads data/bots.json.
    def self.load_yaml(path)
      json_path = Agentry.root.join("data", path.to_s.sub(/\.yml\z/, ".json"))
      return JSON.load_file(json_path) if json_path.file?

      require "yaml"
      YAML.load_file(Agentry.root.join(path))
    end

    def self.bots
      @bots ||= Agentry.load_data("bots")
    end

    def self.bot_exceptions
      @bot_exceptions ||= Agentry.load_data("bot_exceptions")
    end

    def self.search_engines
      @search_engines ||= Agentry.load_data("search_engines")
    end

    def self.category_by_keyword
      @category_by_keyword ||=
        Agentry.load_data("bot_categories").each_with_object({}) do |(category, keywords), category_by_keyword|
          keywords.each { |keyword| category_by_keyword[keyword] = category.to_sym }
        end
    end

    # Builds take this lock and check again under it, rebuild_keywords too: a
    # request that copied a list before a rename never stores its pattern after
    # the rebuild. Reads take none, like the Cache.
    @keywords_mutex = Mutex.new
    @keywords_pattern_by_list = {}.compare_by_identity

    # One regexp per keyword list (an Array, or a Hash keyed by keyword),
    # rebuilt when the list is replaced or changes: the few bot exceptions are
    # compared entry by entry, a Hash by its size, and rebuild_keywords
    # compares every list after an entry renamed in place.
    def self.keywords_pattern(keywords)
      current_keywords_pattern(keywords) ||
        @keywords_mutex.synchronize { current_keywords_pattern(keywords) || build_keywords_pattern(keywords) }
    end

    def self.current_keywords_pattern(keywords)
      words, pattern = @keywords_pattern_by_list[keywords]
      pattern if words && (keywords.is_a?(Hash) ? words.size == keywords.size : words == keywords)
    end

    # From one copy of the list, kept with the pattern: another thread may
    # change the list meanwhile. Frozen copies of the entries too, so that an
    # exception changed with String#replace no longer equals its copy.
    def self.build_keywords_pattern(keywords)
      words = (keywords.is_a?(Hash) ? keywords.keys : keywords.map { |word| word.dup.freeze }).freeze
      pattern = Regexp.new(trie_source(words.map(&:to_s)))
      @keywords_pattern_by_list[keywords] = [words, pattern]
      pattern
    end

    # Run by Agentry.cache_size=: rebuilds at once the patterns and trie whose
    # list changed in place, and only those, so that a cache size set after
    # Agentry.eager_load! leaves nothing for the first request.
    def self.rebuild_keywords
      @keywords_mutex.synchronize do
        # Over a copy: the loop adds to the Hash it reads.
        @keywords_pattern_by_list.to_a.each do |keywords, (words, _pattern)|
          build_keywords_pattern(keywords) unless (keywords.is_a?(Hash) ? keywords.keys : keywords) == words
        end
        list, keywords, = @known_bots_trie
        build_known_bots_trie if list && !(list.equal?(bots) && list.keys == keywords)
      end
    end

    # bots.yml keywords nested by byte, each end holding the keyword's rank: a
    # walk follows the few branches a byte opens, where a regexp of a thousand
    # keywords tries most of them. It starts only where the bytes read so far,
    # as one Integer, equal the start of a keyword, from the node they reach.
    def self.known_bots_trie
      current_known_bots_trie || @keywords_mutex.synchronize { current_known_bots_trie || build_known_bots_trie }
    end

    def self.current_known_bots_trie
      list, keywords, trie = @known_bots_trie
      trie if list.equal?(bots) && keywords.size == bots.size
    end

    def self.build_known_bots_trie
      # One read of the list: an app may add a bot from another thread meanwhile.
      list = bots
      keywords = list.keys.freeze
      byte_lists = keywords.map { |keyword| keyword.to_s.bytes }
      prefix_bytes = byte_lists.filter_map { |bytes| bytes.size.nonzero? }.push(MAX_PREFIX_BYTES).min
      trie = {keywords:, prefix_bytes:, prefixes: {}}
      byte_lists.each_with_index do |bytes, rank|
        # An app may add an empty keyword: it never matches, the walk reads a rank one byte in.
        next if bytes.empty?

        leaf = bytes.reduce(trie) { |node, byte| node[byte] ||= {} }
        leaf[:rank] ||= rank
        head = bytes.first(prefix_bytes)
        trie[:prefixes][head.reduce(0) { |prefix, byte| (prefix << 8) | byte }] = trie.dig(*head)
      end
      @known_bots_trie = [list, keywords, trie]
      trie
    end
    private_class_method :current_keywords_pattern, :build_keywords_pattern, :current_known_bots_trie,
      :build_known_bots_trie

    # The rank of a bots.yml keyword the user agent holds: the lowest, or the
    # first one found when `lowest: false`.
    def self.known_bot_rank(ua, lowest: true, trie: known_bots_trie)
      prefixes = trie[:prefixes]
      prefix_bytes = trie[:prefix_bytes]
      mask = (1 << (8 * prefix_bytes)) - 1
      prefix = 0
      found = nil
      ua.bytesize.times do |index|
        prefix = ((prefix << 8) | ua.getbyte(index)) & mask
        next unless index + 1 >= prefix_bytes && (node = prefixes[prefix])

        position = index + 1
        while node
          rank = node[:rank]
          if rank
            return rank unless lowest

            found = rank if found.nil? || rank < found
          end
          node = node[ua.getbyte(position)]
          position += 1
        end
      end
      found
    end

    # A Regexp.union of hundreds of words tries each of them at every
    # position; nested by common prefix, the regexp follows a single branch
    # per character.
    def self.trie_source(words)
      trie = {}
      words.each do |word|
        leaf = word.each_char.reduce(trie) { |node, char| node[char] ||= {} }
        leaf[:end] = true
      end
      trie_node_source(trie) || "(?!)"
    end

    def self.trie_node_source(node)
      # A shorter keyword matches wherever a longer one would.
      return "" if node.key?(:end)

      branches = node.map do |char, child|
        Regexp.escape(char) + trie_node_source(child)
      end
      (branches.size == 1) ? branches.first : "(?:#{branches.join("|")})"
    end
    private_class_method :trie_source, :trie_node_source

    def self.why?(ua)
      ua = ua.scrub unless ua.valid_encoding?
      ua = ua.downcase.strip
      browser = Agentry.new(ua)
      matchers.find { |matcher| matcher.call(ua, browser) }
    end

    attr_reader :ua

    def initialize(ua)
      @ua = ua.downcase.strip
    end

    # A bot is shared by the browsers of its user agent: each answer holds
    # until a matcher list or the bot list changes.
    def bot?
      generation = Cache.generation
      unless @bot&.first == generation
        @bot = [generation, !bot_exception? && detect_bot?]
      end
      @bot.last
    end

    def why?
      self.class.matchers.find { |matcher| matcher.call(ua, self) }
    end

    def search_engine?
      ua.match?(self.class.keywords_pattern(self.class.search_engines))
    end

    def name
      return unless bot?

      generation = Cache.generation
      unless @name&.first == generation
        @name = [generation, self.class.bots[known_bot_keyword] || GENERIC_NAME]
      end
      @name.last
    end

    # Test drivers have a category, but no bot? (bot_categories.yml).
    def category
      return if bot_exception?

      keyword = bot? && known_bot_keyword
      keyword ||= ua[self.class.keywords_pattern(self.class.category_by_keyword)]
      self.class.category_by_keyword[keyword]
    end

    def ai?
      AI_CATEGORIES.include?(category)
    end

    def user_triggered?
      USER_TRIGGERED_CATEGORIES.include?(category)
    end

    # The owner publishing the IP ranges of the crawler this user agent claims
    # to be (:google, :bing, :openai, :apple, :perplexity, :duckduckgo).
    def owner
      return unless bot?

      @owner = IPRanges.owner(ua) unless defined?(@owner)
      @owner
    end

    # Whether the IP belongs to the owner's published ranges. reverse_dns: true
    # also asks the DNS for an IP outside them (Google, Bing and Apple): two
    # network queries.
    def verified?(ip, reverse_dns: false)
      return false unless owner

      IPRanges.include?(owner, ip) || (reverse_dns && IPRanges.verified_by_dns?(owner, ip))
    end

    # The rank and its keyword from the same trie: another thread may rebuild it meanwhile.
    private def known_bot_keyword
      trie = self.class.known_bots_trie
      rank = self.class.known_bot_rank(ua, trie:)
      trie[:keywords][rank] if rank
    end

    private def bot_exception?
      ua.match?(self.class.keywords_pattern(self.class.bot_exceptions))
    end

    private def detect_bot?
      self.class.matchers.any? do |matcher|
        matcher.call(ua, default_matchers.include?(matcher) ? nil : browser)
      end
    end

    # The built-in matchers ignore the browser: building it would detect the
    # user agent twice.
    private def default_matchers
      DEFAULT_MATCHERS
    end

    private def browser
      @browser ||= Agentry.new(ua)
    end

    private :ua
  end
end
