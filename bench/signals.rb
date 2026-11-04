# frozen_string_literal: true

# What the request signals cost on top of the user agent: client hints,
# Cloudflare headers, and the verified crawler IP lookup.
#   ruby [--yjit] -I lib bench/signals.rb
require "browser"

CHROME = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) " \
         "Chrome/142.0.0.0 Safari/537.36"
GOOGLEBOT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
LOW_ENTROPY_HINTS = {
  "HTTP_SEC_CH_UA" => '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
  "HTTP_SEC_CH_UA_MOBILE" => "?0",
  "HTTP_SEC_CH_UA_PLATFORM" => '"Windows"'
}.freeze
WINDOWS_11_HINTS = LOW_ENTROPY_HINTS.merge("HTTP_SEC_CH_UA_PLATFORM_VERSION" => '"19.0.0"').freeze
CLOUDFLARE_HEADERS = {
  "HTTP_X_BOT_VERIFIED" => "true", "HTTP_X_BOT_CATEGORY" => "Search Engine Crawler",
  "HTTP_X_BOT_SCORE" => "1", "HTTP_CF_IPCOUNTRY" => "US"
}.freeze

def request(headers)
  browser = Browser.new(CHROME, headers:)
  [browser.platform.name, browser.platform.version, browser.device.mobile?, browser.device.tablet?]
end

def cloudflare(headers)
  cloudflare = Browser.new(GOOGLEBOT, headers:).cloudflare
  [cloudflare.verified_bot?, cloudflare.bot_category, cloudflare.bot_score, cloudflare.country]
end

def measure(label, iterations = 200_000)
  yield
  timings = Array.new(7) do
    GC.start
    allocated = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    iterations.times { yield }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    [elapsed / iterations * 1e6, (GC.stat(:total_allocated_objects) - allocated) / iterations]
  end
  printf("%-42s %8.2f µs  %5d objects\n", label, timings.map(&:first).sort[3], timings.first.last)
end

measure("platform and device, no headers") { request(nil) }
measure("platform and device, low-entropy hints") { request(LOW_ENTROPY_HINTS) }
measure("platform and device, Windows 11 hints") { request(WINDOWS_11_HINTS) }
measure("Cloudflare headers") { cloudflare(CLOUDFLARE_HEADERS) }

bot = Browser.new(GOOGLEBOT).bot
measure("bot.verified?, Googlebot IPv4") { bot.verified?("66.249.66.1") }
measure("bot.verified?, Googlebot IPv6") { bot.verified?("2001:4860:4801:10::1") }
measure("bot.verified?, IPv4 outside the ranges") { bot.verified?("203.0.113.7") }
measure("bot.verified?, invalid IP") { bot.verified?("not an IP") }
measure("bot.verified?, a browser") { Browser.new(CHROME).bot.verified?("66.249.66.1") }
