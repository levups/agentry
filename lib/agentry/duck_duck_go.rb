# frozen_string_literal: true

module Agentry
  class DuckDuckGo < Base
    def id
      :duckduckgo
    end

    def name
      "DuckDuckGo"
    end

    def full_version
      ua[%r{DuckDuckGo/([\d.]+)}, 1] ||
        "0.0"
    end

    def match?
      ua.include?("DuckDuckGo")
    end
  end
end
