# frozen_string_literal: true

module Agentry
  class Bot
    class EmptyUserAgentMatcher
      def self.call(ua, _browser)
        ua == ""
      end
    end
  end
end
