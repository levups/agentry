# frozen_string_literal: true

module Agentry
  module Meta
    class Mobile < Base
      def meta
        "mobile" if browser.device.mobile?
      end
    end
  end
end
