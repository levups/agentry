# frozen_string_literal: true

module Browser
  class Bot
    class KnownBotsMatcher
      # Matching hundreds of keywords is the costliest question of a request,
      # and a request asks it twice (`bot?`, then `bot.name`). The answer is
      # kept until the next GC, under a frozen copy of the user agent (the
      # caller's string may change), and for the current trie only: the one
      # built when the bot list changes starts afresh.
      def self.call(ua, _browser)
        matched_by_user_agent = matched_by_user_agent_for(Browser::Bot.known_bots_trie)
        matched = matched_by_user_agent[ua]
        return matched unless matched.nil?

        matched_by_user_agent[-ua] = !Browser::Bot.known_bot_rank(ua, lowest: false).nil?
      end

      def self.matched_by_user_agent_for(trie)
        trie_cache = @trie_cache
        return trie_cache.last if trie_cache&.first.equal?(trie)

        matched_by_user_agent = ObjectSpace::WeakKeyMap.new
        @trie_cache = [trie, matched_by_user_agent].freeze
        matched_by_user_agent
      end
      private_class_method :matched_by_user_agent_for
    end
  end
end
