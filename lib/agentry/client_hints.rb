# frozen_string_literal: true

module Agentry
  # The User-Agent Client Hints of Chromium browsers, read from a Rack env.
  # Safari and Firefox send none: every answer is then nil.
  class ClientHints
    # A browser's hints are a few dozen bytes: longer values, and invalid UTF-8, are ignored.
    HEADER_SIZE_LIMIT_BYTES = 512
    # In the order #initialize reads them; Cache.client_hints keys its entries on them.
    HEADER_NAMES = %w[HTTP_SEC_CH_UA HTTP_SEC_CH_UA_MOBILE HTTP_SEC_CH_UA_PLATFORM HTTP_SEC_CH_UA_PLATFORM_VERSION]
      .freeze
    PLATFORM_CLASS_BY_NAME = {
      "Android" => Platform::Android,
      "Chrome OS" => Platform::ChromeOS,
      "Linux" => Platform::Linux,
      "macOS" => Platform::Mac,
      "Windows" => Platform::Windows
    }.freeze
    # https://learn.microsoft.com/en-us/microsoft-edge/web-platform/how-to-detect-win11
    WINDOWS_11_PLATFORM_VERSION = 13
    BRAND_PATTERN = /"([^"\\]*)"\s*;\s*v\s*=\s*"([^"\\]*)"/
    # GREASE brands, sent so that servers don't depend on the list's order.
    GREASE_BRAND_PATTERN = /\ANot.A.Brand\z/i
    QUOTED_STRING_PATTERN = /\A\s*"([^"\\]+)"\s*\z/
    MOBILE_BY_VALUE = {"?1" => true, "?0" => false}.freeze

    # Brand versions keyed by brand ("Google Chrome" => "142"), from Sec-CH-UA.
    # Each reader hands out copies: Cache.client_hints shares the frozen
    # originals with every request.
    def version_by_brand
      @version_by_brand.transform_values(&:dup).freeze
    end

    # Sec-CH-UA-Platform ("Windows", "macOS", "Android"…).
    def platform
      @platform&.dup
    end

    # Sec-CH-UA-Platform-Version ("15.0.0"), sent only to a site asking for it
    # with an Accept-CH: Sec-CH-UA-Platform-Version response header.
    def platform_version
      @platform_version&.dup
    end

    def brand_count
      @version_by_brand.size
    end

    def self.header_values(headers)
      HEADER_NAMES.map do |name|
        value = headers[name]
        value if value.is_a?(String) && value.bytesize <= HEADER_SIZE_LIMIT_BYTES && value.valid_encoding?
      end
    end

    def initialize(headers)
      brands, mobile, platform, platform_version = self.class.header_values(headers)
      @version_by_brand = parse_brands(brands)
      @mobile = MOBILE_BY_VALUE[mobile&.strip]
      @platform = quoted_string(platform)
      @platform_version = quoted_string(platform_version)
      freeze
    end

    # Sec-CH-UA-Mobile: nil when the browser did not send it.
    def mobile?
      @mobile
    end

    def platform_class
      PLATFORM_CLASS_BY_NAME[@platform]
    end

    # Windows 11 says "Windows NT 10.0" in its user agent: only its platform
    # version tells it from Windows 10.
    def windows11?
      @platform == "Windows" && @platform_version.to_i >= WINDOWS_11_PLATFORM_VERSION
    end

    private def parse_brands(value)
      return EMPTY_HASH unless value

      value.scan(BRAND_PATTERN).each_with_object({}) do |(brand, version), version_by_brand|
        version_by_brand[brand] = version.freeze unless GREASE_BRAND_PATTERN.match?(brand)
      end.freeze
    end

    # Frozen, like every value: Cache.client_hints hands them to each request.
    private def quoted_string(value)
      value&.[](QUOTED_STRING_PATTERN, 1)&.freeze
    end

    EMPTY_HASH = {}.freeze
    NONE = new(EMPTY_HASH)
  end
end
