# frozen_string_literal: true

module Browser
  class Bot
    class KnownBotsMatcher
      def self.call(ua, _browser)
        !Browser::Bot.known_bot_rank(ua, lowest: false).nil?
      end
    end
  end
end
