# frozen_string_literal: true

module Browser
  module Meta
    def self.rules
      @rules ||= [
        Device,
        GenericBrowser,
        Id,
        IE,
        IOS,
        Mobile,
        Platform,
        Proxy,
        Safari,
        Tablet,
        Webkit
      ]
    end

    def self.get(browser)
      rules.flat_map { |rule| rule.new(browser).to_a }.uniq
    end

    class Base
      # Set the browser instance.
      attr_reader :browser

      def initialize(browser)
        @browser = browser
      end

      def meta
        nil
      end

      def to_a
        meta.to_s.squeeze(" ").split
      end
    end
  end
end
