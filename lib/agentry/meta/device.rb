# frozen_string_literal: true

module Agentry
  module Meta
    class Device < Base
      def meta
        browser.device.id
      end
    end
  end
end
