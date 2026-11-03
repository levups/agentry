# BrowserX

A fork of [fnando/browser](https://github.com/fnando/browser) (MIT, upstream dormant since June 2025) by Level UP
Solutions: same public API, so `gem "browserx"` replaces `gem "browser"` without touching a call site, but
faster, with a bot list kept fresh automatically, and more signals (bot categories, verified crawler IPs,
Cloudflare headers, Client Hints). The roadmap lives in the GitHub issues.

## Non-negotiable: the API stays 1:1

- `Browser.new(ua, accept_language:)`, every predicate and every `require` path of `browser` keep working
  unchanged. New features are additions (`bot.category`), never changed meanings.
- The upstream suite (`bundle exec rake test`) stays green, unmodified. New behaviour gets new tests.
- Every change that is not meant to change an answer proves it on the corpus:

  ```bash
  ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl # upstream baseline
  ruby -I lib script/corpus_snapshot.rb > /tmp/browserx.jsonl
  ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/browserx.jsonl
  ```

  `path/to/upstream` is a plain clone of fnando/browser at `dd88933`. A change meant to change answers (a fresher
  bot list) lists the differences it expects, and the diff must show exactly those.

## Measuring

`bench/request.rb` replays what a web request asks (name, version, `bot?`, platform, device, accept-language)
over 2,000 distinct user agents and over 20 repeated ones, median of 7. Run it without JIT and with `--yjit`,
upstream and branch, one benchmark at a time on an otherwise idle machine:
`ruby --yjit -I lib bench/request.rb`.

Baseline on Ruby 4.0.9, YJIT: upstream 110 µs / 245 objects per request; in 1.0.0
61 µs / 129 objects.

## Data sources

- Allowed (permissive, attribution in `corpus/SOURCES.md` and the README): monperrus/crawler-user-agents (MIT),
  ai-robots-txt/ai.robots.txt (MIT), ua-parser/uap-core (Apache 2.0), IP ranges published by the crawlers'
  owners (Google, Bing, OpenAI, Apple, Perplexity…).
- Never embedded: matomo-org/device-detector (LGPL-3.0; usable locally as an oracle, never shipped), the
  Cloudflare Radar bots directory (CC BY-NC). From Cloudflare we only read the headers it sets on requests.

## Known trap

`crawler-user-agents` calls "bot" anything that is not a human browser: crawlers, but also test drivers
(Playwright, Puppeteer, Selenium), scripts (`curl`, `got`) and scanners. Widening `bot?` with it blindly would
flag the system tests of apps using BrowserX. Keep the categories apart.
