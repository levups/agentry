# frozen_string_literal: true

module Agentry
  class Device
    class Iphone < Base
      def id
        :iphone
      end

      def name
        "iPhone"
      end

      def match?
        ua.include?("iPhone")
      end
    end
  end
end
