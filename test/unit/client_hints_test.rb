# frozen_string_literal: true

require "test_helper"

class ClientHintsTest < Minitest::Test
  # Chromium freezes its user agent: Windows 11, macOS 15 and Android 15 send these.
  WINDOWS_CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " \
                   "Chrome/142.0.0.0 Safari/537.36"
  MAC_CHROME = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) " \
               "Chrome/142.0.0.0 Safari/537.36"
  ANDROID_CHROME = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) " \
                   "Chrome/142.0.0.0 Mobile Safari/537.36"
  LINUX_CHROME = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) " \
                 "Chrome/142.0.0.0 Safari/537.36"
  BRANDS = '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"'

  def hints(platform: nil, platform_version: nil, mobile: nil, brands: BRANDS)
    {
      "HTTP_SEC_CH_UA" => brands,
      "HTTP_SEC_CH_UA_MOBILE" => mobile,
      "HTTP_SEC_CH_UA_PLATFORM" => platform && %("#{platform}"),
      "HTTP_SEC_CH_UA_PLATFORM_VERSION" => platform_version && %("#{platform_version}")
    }.compact
  end

  setup do
    Agentry.cache_size = 1000
  end

  teardown do
    Agentry.cache_size = 1000
  end

  test "parses the brands, without the GREASE one" do
    client_hints = Agentry.new(WINDOWS_CHROME, headers: hints).client_hints

    assert_equal({"Chromium" => "142", "Google Chrome" => "142"}, client_hints.version_by_brand)
  end

  test "parses the platform, its version and the mobile flag" do
    client_hints = Agentry::ClientHints.new(hints(platform: "macOS", platform_version: "15.1.0", mobile: "?0"))

    assert_equal "macOS", client_hints.platform
    assert_equal "15.1.0", client_hints.platform_version
    assert_equal false, client_hints.mobile?
    assert_equal true, Agentry::ClientHints.new(hints(mobile: "?1")).mobile?
  end

  test "answers nil for hints a browser did not send or malformed ones" do
    client_hints = Agentry::ClientHints.new(
      "HTTP_SEC_CH_UA_MOBILE" => "yes", "HTTP_SEC_CH_UA_PLATFORM" => "Windows",
      "HTTP_SEC_CH_UA_PLATFORM_VERSION" => %("#{"1" * 600}")
    )

    assert_nil client_hints.mobile?
    assert_nil client_hints.platform
    assert_nil client_hints.platform_version
    assert_empty client_hints.version_by_brand
    assert_nil Agentry.new(WINDOWS_CHROME).client_hints.platform
  end

  test "ignores a hint that is not valid UTF-8" do
    invalid = hints(platform: "Windows\xFF", platform_version: "19.0.0\xFF", brands: "#{BRANDS}\xFF")
      .transform_values { |value| value.dup.force_encoding(Encoding::UTF_8) }
    client_hints = Agentry::ClientHints.new(invalid)

    assert_empty client_hints.version_by_brand
    assert_nil client_hints.platform
    assert_nil client_hints.platform_version
    refute Agentry.new(WINDOWS_CHROME, headers: invalid).platform.windows11?
  end

  test "tells Windows 11 from Windows 10" do
    windows11 = Agentry.new(WINDOWS_CHROME, headers: hints(platform: "Windows", platform_version: "19.0.0")).platform
    windows10 = Agentry.new(WINDOWS_CHROME, headers: hints(platform: "Windows", platform_version: "10.0.0")).platform

    assert windows11.windows11?
    refute windows11.windows10?
    assert_equal "11", windows11.version
    refute windows10.windows11?
    assert windows10.windows10?
    assert_equal "10.0", windows10.version
  end

  test "takes the platform version from the hints" do
    mac = Agentry.new(MAC_CHROME, headers: hints(platform: "macOS", platform_version: "15.1.0")).platform
    android = Agentry.new(ANDROID_CHROME, headers: hints(platform: "Android", platform_version: "15.0.0")).platform

    assert_equal "15.1.0", mac.version
    assert mac.mac?(">= 15")
    assert_equal "macOS", mac.name
    assert android.android?(">= 15")
  end

  test "takes the platform and the mobile flag from the hints" do
    # Chrome for Android's "desktop site" sends a desktop Linux user agent.
    browser = Agentry.new(LINUX_CHROME, headers: hints(platform: "Android", mobile: "?0"))

    assert browser.platform.android?
    assert browser.device.tablet?
    refute browser.device.mobile?
    assert Agentry.new(LINUX_CHROME, headers: hints(platform: "Linux", mobile: "?1")).device.mobile?
  end

  test "falls back on the user agent without hints" do
    browser = Agentry.new(WINDOWS_CHROME, headers: {})

    assert browser.platform.windows10?
    refute browser.platform.windows11?
    assert_equal "10.0", browser.platform.version
    refute Agentry.new(MAC_CHROME, headers: hints(platform: "Fuchsia", platform_version: "1.0")).platform.windows?
  end

  test "keeps the user agent's cached platform and device when the hints agree with it" do
    plain = Agentry.new(ANDROID_CHROME)
    hinted = Agentry.new(ANDROID_CHROME, headers: hints(platform: "Android", mobile: "?1"))

    assert_same plain.platform, hinted.platform
    assert_same plain.device, hinted.device
  end

  test "never caches an answer that depends on the hints" do
    windows11 = hints(platform: "Windows", platform_version: "19.0.0")

    assert Agentry.new(WINDOWS_CHROME, headers: windows11).platform.windows11?
    refute Agentry.new(WINDOWS_CHROME).platform.windows11?
    assert Agentry.new(WINDOWS_CHROME, headers: windows11).platform.windows11?
    refute Agentry.new(LINUX_CHROME, headers: hints(platform: "Linux", mobile: "?1")).device.tablet?
    refute Agentry.new(LINUX_CHROME).device.mobile?
  end

  test "answers each request from its own hints when they change for a user agent" do
    windows11 = hints(platform: "Windows", platform_version: "19.0.0", mobile: "?0")
    windows10 = hints(platform: "Windows", platform_version: "10.0.0", mobile: "?1")

    2.times do
      assert_equal "11", Agentry.new(WINDOWS_CHROME, headers: windows11).platform.version
      refute Agentry.new(WINDOWS_CHROME, headers: windows11).device.mobile?
      assert_equal "10.0", Agentry.new(WINDOWS_CHROME, headers: windows10).platform.version
      assert Agentry.new(WINDOWS_CHROME, headers: windows10).device.mobile?
    end
  end

  test "hands out hints no request can change for the next" do
    mac = hints(platform: "macOS", platform_version: "15.1.0")
    client_hints = Agentry.new(MAC_CHROME, headers: mac).client_hints

    client_hints.platform << "x"
    client_hints.platform_version << "x"
    client_hints.version_by_brand["Chromium"] << "x"
    hinted = Agentry.new(MAC_CHROME, headers: mac).client_hints
    assert_equal ["macOS", "15.1.0", "142"], [hinted.platform, hinted.platform_version, hinted.version_by_brand["Chromium"]]
    Agentry.new(MAC_CHROME, headers: mac).platform.version << "-changed"
    assert_equal "15.1.0", Agentry.new(MAC_CHROME, headers: mac).platform.version
  end

  test "gives each thread its own hints while others fill and empty the cache" do
    Agentry.cache_size = 2
    versions = %w[19.0.0 10.0.0 15.0.0 13.0.0]
    threads = versions.map do |version|
      Thread.new do
        Array.new(2_000) do
          Thread.pass # interleave the readers with the inserts and the flushes
          Agentry.new(WINDOWS_CHROME, headers: hints(platform: "Windows", platform_version: version))
        end
          .map { |browser| browser.client_hints.platform_version }.uniq
      end
    end

    assert_equal versions.zip, threads.map(&:value)
  end

  test "ignores a Cloudflare header in an encoding its patterns can't read" do
    browser = Agentry.new(WINDOWS_CHROME, headers: {"HTTP_X_BOT_SCORE" => "1".encode("UTF-16LE")})

    assert_nil browser.cloudflare.bot_score
  end

  test "ignores a hint in an encoding its patterns can't read" do
    utf16 = hints(platform: "Windows").merge("HTTP_SEC_CH_UA_PLATFORM" => %("Windows").encode("UTF-16LE"))

    assert_nil Agentry.new(WINDOWS_CHROME, headers: utf16).client_hints.platform
    assert Agentry.new(WINDOWS_CHROME, headers: utf16).platform.windows?
  end

  test "reads hints alike with the cache off and from forged values" do
    windows11 = hints(platform: "Windows", platform_version: "19.0.0")
    forged = windows11.merge("HTTP_SEC_CH_UA_PLATFORM_VERSION" => ["19.0.0"])
    oversized = windows11.merge("HTTP_SEC_CH_UA" => %("#{"a" * 600}";v="1"))

    assert Agentry.new(WINDOWS_CHROME, headers: forged).platform.windows?
    refute Agentry.new(WINDOWS_CHROME, headers: forged).platform.windows11?
    assert_empty Agentry.new(WINDOWS_CHROME, headers: oversized).client_hints.version_by_brand
    many_brands = Array.new(20) { |index| %("Brand #{index}";v="1") }.join(", ")
    assert_equal 20, Agentry.new(WINDOWS_CHROME, headers: hints(brands: many_brands)).client_hints.version_by_brand.size
    assert_equal 20, Agentry.new(WINDOWS_CHROME, headers: hints(brands: many_brands)).client_hints.version_by_brand.size
    assert Agentry.new(WINDOWS_CHROME, headers: windows11).platform.windows11?
    Agentry.cache_size = 0
    assert Agentry.new(WINDOWS_CHROME, headers: windows11).platform.windows11?
  end
end
