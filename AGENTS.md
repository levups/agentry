# BrowserX

Fork of [fnando/browser](https://github.com/fnando/browser) (MIT, dormant since June 2025) by Level UP Solutions:
`gem "browserx"` replaces `gem "browser"` without touching a call site, but faster, with a bot list kept fresh and
more signals (bot categories, verified crawler IPs, Cloudflare headers, Client Hints). Roadmap: the GitHub issues.

## The API stays 1:1

- `Browser.new(ua, accept_language:)`, every predicate and every `require` path of `browser` keep working
  unchanged. New features are additions (`bot.category`), never changed meanings.
- The upstream suite (`bundle exec rake test`) stays green, unmodified. New behaviour gets new tests.
- Supported: every maintained Ruby and Rails (endoflife.date), today Ruby 3.3+ and Rails 8.0, 8.1. CI
  (`.github/workflows/ci.yml`) runs RuboCop, then the tests on each of them: `bundle exec rubocop` stays clean.

## Corpus diff

A change not meant to change an answer proves it on the 20,328 user agents of `corpus/`:

```bash
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl # fnando/browser at dd88933
ruby -I lib script/corpus_snapshot.rb > /tmp/browserx.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/browserx.jsonl
```

A change meant to change answers (a fresher bot list) lists the differences it expects; the diff shows exactly
those.

## Benchmark

`bench/request.rb` replays a web request's questions (name, version, `bot?`, platform, device, accept-language)
over 2,000 distinct user agents and 20 repeated ones, median of 7. Run upstream and branch, without JIT and with
`--yjit`, one at a time on an idle machine: `ruby --yjit -I lib bench/request.rb`. Ruby 4.0.9, YJIT: browser
6.2.0 110 µs / 245 objects per request, BrowserX 1.0.0 61 µs / 129 objects.

## Data source licences

- Allowed, credited in `corpus/SOURCES.md` and the README: monperrus/crawler-user-agents (MIT),
  ai-robots-txt/ai.robots.txt (MIT), ua-parser/uap-core (Apache 2.0), IP ranges published by the crawlers'
  owners (Google, Bing, OpenAI, Apple, Perplexity…).
- Never embedded: matomo-org/device-detector (LGPL-3.0; a local oracle at most), the Cloudflare Radar bots
  directory (CC BY-NC). From Cloudflare we only read the headers it sets on requests.

## Traps

- `crawler-user-agents` calls "bot" anything that is not a human browser: crawlers, but also test drivers
  (Playwright, Puppeteer, Selenium), scripts (`curl`, `got`) and scanners. Widening `bot?` with it blindly would
  flag the system tests of apps using BrowserX: keep the categories apart.
- `lib/browser/testing.rb` reads `test/ua*.yml` at runtime: those fixtures ship in the gem, keep them in
  `s.files`.
