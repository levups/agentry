# frozen_string_literal: true

module Agentry
  class Platform
    class Base
      attr_reader :ua, :platform

      def initialize(ua, platform = nil)
        @ua = ua
        @platform = platform
      end

      def match?
        false
      end
    end
  end
end
