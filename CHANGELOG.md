# Changelog

## 1.0.0

First release as `browserx`, forked from browser 6.2.0 (`dd88933`). Same API: `gem "browserx"` replaces
`gem "browser"` without touching a call site.

- Detect bots through one prefix-trie regexp instead of one match per entry, and without detecting the browser
  twice; build platform and device matchers lazily. A request takes 45% less time and half the allocations.
- Load Rails, not only its railtie, so the railtie works without a preloaded ActiveSupport.
- Add a corpus of 20,328 user agents with snapshot and diff scripts proving answers match upstream, and a
  request benchmark.
- Add `lib/browserx.rb`, so Bundler's auto-require loads the gem.
- Require Ruby 3.3 or later: 3.2 reached its end of life on 2026-03-31.
- Test against Rails 8.0 and 8.1 only: 7.0, 7.1 and 7.2 reached their end of life.

Earlier versions are those of browser: see its [changelog](https://github.com/fnando/browser/blob/main/CHANGELOG.md).
