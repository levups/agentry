# frozen_string_literal: true

module Agentry
  module Meta
    class Id < Base
      def meta
        browser.id
      end
    end
  end
end
