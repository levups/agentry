# frozen_string_literal: true

module Browser
  # What a user agent is detected as, shared by every browser built from it
  # while it stays in the cache. Each answer is computed on first use.
  class Detection
    attr_accessor :browser_class

    def initialize(ua)
      @ua = ua
    end

    def platform
      @platform ||= Platform.new(@ua)
    end

    def device
      @device ||= Device.new(@ua, platform:)
    end

    def bot
      @bot ||= Bot.new(@ua)
    end
  end
end
