# frozen_string_literal: true

module Agentry
  module Meta
    class Platform < Base
      def meta
        browser.platform.id
      end
    end
  end
end
