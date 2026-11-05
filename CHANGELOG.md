# Changelog

## [Unreleased]

## [2.1.0] — 2026-11-05

The first request of each process gets cheaper: the lists ship as JSON, and `Browser.eager_load!` builds them
before a server forks.

**New**
- `Browser.eager_load!` loads the lists and builds the matchers and bot keyword tries up front, so a server that
  preloads its app before forking (Puma, Unicorn, Pitchfork) shares them with every worker. Rails calls it on its
  own when it eager loads, which production does by default. A worker's first request spent 12.9 ms building
  them, 0.2 ms once built.

**Faster**
- The lists ship as JSON: without Bootsnap's cache, a process's first request is 3× faster (12.4 → 4.0 ms with
  YJIT, 7.5 → 2.7 ms without), and `require "browser"` no longer loads Psych (32 → 21 ms with YJIT, 28 → 22 ms
  without). With Bootsnap, nothing changes. Code that used `YAML` without requiring it now needs its own
  `require "yaml"`.

## [2.0.0] — 2026-11-04

A repeated user agent is now answered in 2 µs, about 600 more bots are recognised, and bots, Cloudflare headers and
Client Hints can be checked against the request. Without the new headers, every answer stays browser 6.2.0's,
except bot detection, which finds more bots.

**Breaking**
- `bot?` is true for about 600 more user agents: bots from crawler-user-agents and ai.robots.txt, synced weekly,
  add 1,247 entries to `bots.yml`. Of the crawlers added there since 2024, browser misses 353 out of 882 and
  BrowserX 11. Analytics that filter on `bot?` will count fewer humans from the day you switch.
- The Rails helper and the middleware now pass the request's headers, so Client Hints refine the answers on
  Chromium: Windows 11 is no longer `windows10?`, and Chrome for Android in desktop mode is an Android tablet,
  not a Linux desktop.

**New**
- `bot.category` (16 categories, close to Cloudflare's verified bot categories), `bot.ai?` and
  `bot.user_triggered?`. Test drivers (Playwright, Puppeteer, Selenium, headless Chrome) get the
  `browser_automation` category but are not bots, so system tests keep running as humans.
- `bot.verified?(ip)` checks a crawler against the IP ranges its owner publishes (Google, Bing, OpenAI, Apple,
  Perplexity, DuckDuckGo), shipped with the gem and refreshable at runtime; reverse DNS is opt-in. `bot.owner`
  names the owner.
- `Browser.new(ua, headers: request.env)` reads Cloudflare's bot headers (`browser.cloudflare`: verified bot,
  category, score, country; header names configurable) and Chromium's Client Hints (`browser.client_hints`,
  `platform.windows11?`).
- `Browser.cache_size` (default 1,000, `0` turns it off) bounds the new per-user-agent cache: about 1 KB per
  entry, so about 1 MB per process.

**Faster**
- Answers are cached per user agent, matchers that can't match are skipped, and bots are found through a byte
  trie. Ruby 4.0.9: a repeated user agent takes 1.8 µs instead of 57.5 with YJIT and 3.6 µs instead of 72.5
  without; 2,000 distinct user agents take 24.2 µs instead of 62.4 with YJIT and 43.9 µs instead of 77.3
  without. Objects per request: 9 instead of 116 repeated, 50 instead of 125 distinct.

**Fixed**
- Loading `browser` and `browserx` together raises a clear `LoadError` instead of one silently overriding the
  other.

## [1.0.0] — 2026-11-04

First release as `browserx`, forked from browser 6.2.0 (`dd88933`). Same API: `gem "browserx"` replaces
`gem "browser"` without touching a call site. Earlier versions are browser's: see its
[changelog](https://github.com/fnando/browser/blob/main/CHANGELOG.md).

**Breaking**
- Requires Ruby 3.3 or later: 3.2 reached its end of life on 2026-03-31.
- Tested against Rails 8.0 and 8.1 only: 7.0, 7.1 and 7.2 reached their end of life.

**Faster**
- Bots are detected through one prefix-trie regexp instead of one match per entry, and without detecting the
  browser twice; platform and device matchers are built lazily. A request takes 45% less time and half the
  allocations.

**Fixed**
- The railtie loads Rails, not only itself, so it works without a preloaded ActiveSupport.
- `lib/browserx.rb` exists, so Bundler's auto-require loads the gem.

**New**
- A corpus of 20,328 user agents, with snapshot and diff scripts proving answers match upstream, and a
  request benchmark.

[Unreleased]: https://github.com/next-gen-gems/browserx/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/next-gen-gems/browserx/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/next-gen-gems/browserx/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/next-gen-gems/browserx/releases/tag/v1.0.0
