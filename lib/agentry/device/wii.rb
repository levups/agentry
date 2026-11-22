# frozen_string_literal: true

module Agentry
  class Device
    class Wii < Base
      def id
        :wii
      end

      def name
        "Nintendo Wii"
      end

      def match?
        ua.match?(/Nintendo Wii/i)
      end
    end
  end
end
