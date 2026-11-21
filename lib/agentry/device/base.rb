# frozen_string_literal: true

module Agentry
  class Device
    class Base
      attr_reader :ua

      def initialize(ua)
        @ua = ua
      end
    end
  end
end
