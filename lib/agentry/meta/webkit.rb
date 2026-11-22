# frozen_string_literal: true

module Agentry
  module Meta
    class Webkit < Base
      def meta
        "webkit" if browser.webkit?
      end
    end
  end
end
