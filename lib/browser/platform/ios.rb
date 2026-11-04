# frozen_string_literal: true

module Browser
  class Platform
    class IOS < Base
      MATCHER = /(iPhone|iPad|iPod|CriOS)/
      VERSION_MATCHER =
        /OS (?<major>\d+)_(?<minor>\d+)_?(?<patch>\d+)?/

      def version
        case VERSION_MATCHER.match(ua)
        in nil then "0"
        in {major:, minor:, patch: String => patch} then "#{major}.#{minor}.#{patch}"
        in {major:, minor: "0"} then major
        in {major:, minor:} then "#{major}.#{minor}"
        end
      end

      def name
        "iOS (#{device})"
      end

      def id
        :ios
      end

      def match?
        ua.match?(MATCHER)
      end

      def device
        ua[MATCHER, 1]
      end
    end
  end
end
