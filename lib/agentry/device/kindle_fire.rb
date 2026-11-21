# frozen_string_literal: true

module Agentry
  class Device
    class KindleFire < Base
      def id
        :kindle_fire
      end

      def name
        "Kindle Fire"
      end

      def match?
        ua.match?(/Kindle Fire|KFTT/)
      end
    end
  end
end
