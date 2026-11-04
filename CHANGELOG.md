# Changelog

## [Unreleased]

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
