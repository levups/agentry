# frozen_string_literal: true

module Agentry
  module Meta
    class Proxy < Base
      def meta
        "proxy" if browser.proxy?
      end
    end
  end
end
