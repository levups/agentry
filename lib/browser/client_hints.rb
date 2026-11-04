# frozen_string_literal: true

module Browser
  # The User-Agent Client Hints of Chromium browsers, read from a Rack env.
  # Safari and Firefox send none: every answer is then nil.
  class ClientHints
    # A browser's hints are a few dozen bytes: longer values are ignored.
    HEADER_SIZE_LIMIT_BYTES = 512
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
    attr_reader :version_by_brand
    # Sec-CH-UA-Platform ("Windows", "macOS", "Android"…).
    attr_reader :platform
    # Sec-CH-UA-Platform-Version ("15.0.0"), sent only to a site asking for it
    # with an Accept-CH: Sec-CH-UA-Platform-Version response header.
    attr_reader :platform_version

    def initialize(headers)
      @version_by_brand = parse_brands(header(headers, "HTTP_SEC_CH_UA"))
      @mobile = MOBILE_BY_VALUE[header(headers, "HTTP_SEC_CH_UA_MOBILE")&.strip]
      @platform = quoted_string(header(headers, "HTTP_SEC_CH_UA_PLATFORM"))
      @platform_version = quoted_string(header(headers, "HTTP_SEC_CH_UA_PLATFORM_VERSION"))
      freeze
    end

    # Sec-CH-UA-Mobile: nil when the browser did not send it.
    def mobile?
      @mobile
    end

    def platform_class
      PLATFORM_CLASS_BY_NAME[platform]
    end

    # Windows 11 says "Windows NT 10.0" in its user agent: only its platform
    # version tells it from Windows 10.
    def windows11?
      platform == "Windows" && platform_version.to_i >= WINDOWS_11_PLATFORM_VERSION
    end

    private def header(headers, name)
      value = headers[name]
      value if value.is_a?(String) && value.bytesize <= HEADER_SIZE_LIMIT_BYTES
    end

    private def parse_brands(value)
      return EMPTY_HASH unless value

      value.scan(BRAND_PATTERN).to_h.reject { |brand, _version| GREASE_BRAND_PATTERN.match?(brand) }.freeze
    end

    private def quoted_string(value)
      value&.[](QUOTED_STRING_PATTERN, 1)
    end

    EMPTY_HASH = {}.freeze
    NONE = new(EMPTY_HASH)
  end
end
