# frozen_string_literal: true

module Agentry
  module Meta
    class Tablet < Base
      def meta
        "tablet" if browser.device.tablet?
      end
    end
  end
end
