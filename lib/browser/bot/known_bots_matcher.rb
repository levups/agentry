# frozen_string_literal: true

module Browser
  class Bot
    class KnownBotsMatcher
      def self.call(ua, _browser)
        ua.match?(Browser::Bot.keywords_pattern(Browser::Bot.bots))
      end
    end
  end
end
