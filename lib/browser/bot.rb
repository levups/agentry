# frozen_string_literal: true

module Browser
  class Bot
    GENERIC_NAME = "Generic Bot"
    AI_CATEGORIES = %i[ai_agent ai_assistant ai_crawler ai_search].freeze
    USER_TRIGGERED_CATEGORIES = %i[ai_agent ai_assistant].freeze

    def self.matchers
      @matchers ||= default_matchers
    end

    def self.default_matchers
      DEFAULT_MATCHERS.dup
    end

    def self.load_yaml(path)
      YAML.load_file(Browser.root.join(path))
    end

    def self.bots
      @bots ||= load_yaml("bots.yml")
    end

    def self.bot_exceptions
      @bot_exceptions ||= load_yaml("bot_exceptions.yml")
    end

    def self.search_engines
      @search_engines ||= load_yaml("search_engines.yml")
    end

    def self.category_by_keyword
      @category_by_keyword ||=
        load_yaml("bot_categories.yml").each_with_object({}) do |(category, keywords), category_by_keyword|
          keywords.each { |keyword| category_by_keyword[keyword] = category.to_sym }
        end
    end

    # One regexp per keyword list (an Array, or a Hash keyed by keyword),
    # rebuilt when the list grows or is replaced.
    def self.keywords_pattern(keywords)
      @keywords_pattern_by_list ||= {}.compare_by_identity
      size, pattern = @keywords_pattern_by_list[keywords]
      return pattern if size == keywords.size

      words = (keywords.is_a?(Hash) ? keywords.keys : keywords).map(&:to_s)
      pattern = Regexp.new(trie_source(words))
      @keywords_pattern_by_list[keywords] = [keywords.size, pattern]
      pattern
    end

    # bots.yml keywords nested by byte, each end holding the keyword's rank.
    # Walked from each byte of a user agent, it follows the few branches that
    # byte opens, where a regexp of a thousand keywords tries most of them.
    def self.known_bots_trie
      list, size, trie = @known_bots_trie
      return trie if list.equal?(bots) && size == bots.size

      trie = {keywords: bots.keys}
      trie[:keywords].each_with_index do |keyword, rank|
        leaf = keyword.to_s.each_byte.reduce(trie) { |node, byte| node[byte] ||= {} }
        leaf[:rank] ||= rank
      end
      @known_bots_trie = [bots, bots.size, trie]
      trie
    end

    # The rank of a bots.yml keyword the user agent holds: the lowest, or the
    # first one found when `lowest: false`.
    def self.known_bot_rank(ua, lowest: true)
      trie = known_bots_trie
      found = nil
      ua.bytesize.times do |start|
        node = trie
        position = start
        while (node = node[ua.getbyte(position)])
          rank = node[:rank]
          if rank
            return rank unless lowest

            found = rank if found.nil? || rank < found
          end
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
      ua = ua.downcase.strip
      browser = Browser.new(ua)
      matchers.find { |matcher| matcher.call(ua, browser) }
    end

    attr_reader :ua

    def initialize(ua)
      @ua = ua.downcase.strip
    end

    def bot?
      !bot_exception? && detect_bot?
    end

    def why?
      self.class.matchers.find { |matcher| matcher.call(ua, self) }
    end

    def search_engine?
      ua.match?(self.class.keywords_pattern(self.class.search_engines))
    end

    def name
      return unless bot?

      self.class.bots[known_bot_keyword] || GENERIC_NAME
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

    private def known_bot_keyword
      rank = self.class.known_bot_rank(ua)
      self.class.known_bots_trie[:keywords][rank] if rank
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
      @browser ||= Browser.new(ua)
    end

    private :ua
  end
end
