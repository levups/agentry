# frozen_string_literal: true

module Browser
  class Bot
    class KnownBotsMatcher
      # Matching hundreds of keywords is the costliest question of a request,
      # and a request asks it twice (`bot?`, then `bot.name`). The answer is
      # kept until the next GC, under a frozen copy of the user agent (the
      # caller's string may change), and for the current pattern only: the
      # one built when the bot list changes starts afresh.
      def self.call(ua, _browser)
        pattern = Browser::Bot.keywords_pattern(Browser::Bot.bots)
        matched_by_user_agent = matched_by_user_agent_for(pattern)
        matched = matched_by_user_agent[ua]
        return matched unless matched.nil?

        matched_by_user_agent[-ua] = ua.match?(pattern)
      end

      def self.matched_by_user_agent_for(pattern)
        pattern_cache = @pattern_cache
        return pattern_cache.last if pattern_cache&.first.equal?(pattern)

        matched_by_user_agent = ObjectSpace::WeakKeyMap.new
        @pattern_cache = [pattern, matched_by_user_agent].freeze
        matched_by_user_agent
      end
      private_class_method :matched_by_user_agent_for
    end
  end
end
