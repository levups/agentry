# frozen_string_literal: true

module Agentry
  class Device
    class Samsung < Base
      REGEX = /\(Linux.*?; Android.*?; (SAMSUNG )?(SM-[A-Z0-9]+).*?\)/i

      def self.names
        @names ||= Agentry.load_data("samsung")
      end

      def id
        :samsung
      end

      def name
        "Samsung #{self.class.names[code] || code}"
      end

      def code
        matches && matches[2]
      end

      def matches
        @matches ||= ua.match(REGEX)
      end

      def match?
        !!matches
      end
    end
  end
end
