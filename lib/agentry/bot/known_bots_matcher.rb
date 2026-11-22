# frozen_string_literal: true

module Agentry
  class Bot
    class KnownBotsMatcher
      def self.call(ua, _browser)
        !Agentry::Bot.known_bot_rank(ua, lowest: false).nil?
      end
    end
  end
end
