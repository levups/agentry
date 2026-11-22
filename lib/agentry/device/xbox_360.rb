# frozen_string_literal: true

module Agentry
  class Device
    class Xbox360 < Base
      def id
        :xbox_360
      end

      def name
        "Xbox 360"
      end

      def match?
        ua.match?(/Xbox/i)
      end
    end
  end
end
