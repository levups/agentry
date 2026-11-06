# frozen_string_literal: true

module Browser
  # What Cloudflare knows of the request, from the headers a Transform Rule
  # sets (docs/guide.html#cloudflare) and its own CF-IPCountry. Each site names
  # its headers in its rule: Browser::Cloudflare.header_names= changes them.
  class Cloudflare
    # Cloudflare's values are a few bytes: a longer one is forged, and ignored.
    HEADER_SIZE_LIMIT_BYTES = 128
    DEFAULT_HEADER_NAMES = {
      verified_bot: "X-Bot-Verified",
      bot_category: "X-Bot-Category",
      bot_score: "X-Bot-Score",
      country: "CF-IPCountry"
    }.freeze

    class << self
      attr_reader :header_names, :env_key_by_signal
    end

    # Merged into the defaults: {bot_score: "X-Edge-Bot-Score"}.
    def self.header_names=(names)
      unknown_signals = names.keys - DEFAULT_HEADER_NAMES.keys
      raise ArgumentError, "unknown Cloudflare signals: #{unknown_signals.inspect}" if unknown_signals.any?

      @header_names = DEFAULT_HEADER_NAMES.merge(names).freeze
      @env_key_by_signal = @header_names.transform_values { |name| "HTTP_#{name.upcase.tr("-", "_")}" }.freeze
    end

    self.header_names = {}

    def initialize(headers)
      @headers = headers
    end

    # cf.bot_management.verified_bot (cf.client.bot without Bot Management).
    def verified_bot?
      header(:verified_bot)&.casecmp?("true") || false
    end

    # cf.verified_bot_category, in bot.category's vocabulary: "Monitoring &
    # Analytics" is :monitoring_and_analytics.
    def bot_category
      category = header(:bot_category)&.strip
      return if category.nil? || category.empty?

      category.downcase.gsub("&", "and").gsub(/[^a-z0-9]+/, "_").to_sym
    end

    # cf.bot_management.score, Bot Management only: 1 is a bot, 99 a human.
    def bot_score
      score = header(:bot_score)&.strip
      score.to_i if score&.match?(/\A\d{1,2}\z/)
    end

    # The ISO 3166-1 alpha-2 country, "XX" when unknown, "T1" for Tor.
    def country
      country = header(:country)&.strip
      country if country&.match?(/\A[A-Z0-9]{2}\z/)
    end

    private def header(signal)
      value = @headers&.[](self.class.env_key_by_signal[signal])
      value if value.is_a?(String) && value.bytesize <= HEADER_SIZE_LIMIT_BYTES
    end
  end
end
