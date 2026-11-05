# Agentry

Fork of [fnando/browser](https://github.com/fnando/browser) (MIT, dormant since June 2025) by Level UP Solutions:
`gem "agentry"` replaces `gem "browser"` without touching a call site, but faster, with a bot list kept fresh and
more signals (bot categories, verified crawler IPs, Cloudflare headers, Client Hints). Roadmap: the GitHub issues.

## The API stays 1:1

- `Browser.new(ua, accept_language:)`, every predicate and every `require` path of `browser` keep working
  unchanged. New features are additions (`bot.category`), never changed meanings.
- The upstream suite (`bundle exec rake test`) stays green, unmodified. New behaviour gets new tests.
- Supported: every maintained Ruby and Rails (endoflife.date), today Ruby 3.3+ and Rails 8.0, 8.1. CI
  (`.github/workflows/ci.yml`) runs RuboCop, then the tests on each of them: `bundle exec rubocop` stays clean.

## Corpus diff

A change not meant to change an answer proves it on the 20,328 user agents of `corpus/` (CI's Corpus diff job):

```bash
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl # fnando/browser at dd88933
ruby -I lib script/corpus_snapshot.rb > /tmp/agentry.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/agentry.jsonl
```

A change meant to change answers (a fresher bot list) lists the differences it expects in
`corpus/expected_differences.jsonl` (`corpus_diff.rb --write`); the diff passes when it shows exactly those.
A method upstream lacks (`bot.owner`, `platform.windows11?`) is an addition: the diff only compares upstream's.

## Benchmark

`bench/request.rb` replays a web request's questions (name, version, `bot?`, platform, device, accept-language)
over 2,000 distinct user agents and 20 repeated ones, median of 7. `bundle exec rake bench UPSTREAM=path/to/upstream`
runs upstream and Agentry, without JIT and with `--yjit`, one at a time: run it on an idle machine. Ruby 4.0.9,
YJIT, Apple M4 Max: browser 6.2.0 126 µs / 245 objects per request, Agentry 25 µs / 52 objects on a new user
agent, 2 µs / 12 objects on a repeated one.

## The site

`docs/` is the GitHub Pages site. Its numbers sit between `<!-- render:name -->` markers, rewritten by
`script/render_docs.rb` from `docs/benchmarks.json` (`bench/request.rb --write`), `docs/bot_coverage.json`
(`script/bot_coverage.rb`, the weekly sync), the bot lists and `corpus/expected_differences.jsonl`: never type a
number there, CI's docs job fails when a page differs from what `rake docs:render` writes. A new code block needs
`rake docs:highlight`.

## Data source licences

- Allowed, credited in `corpus/SOURCES.md` and the README: monperrus/crawler-user-agents (MIT),
  ai-robots-txt/ai.robots.txt (MIT), ua-parser/uap-core (Apache 2.0), IP ranges published by the crawlers'
  owners (Google, Bing, OpenAI, Apple, Perplexity…).
- Never embedded: matomo-org/device-detector (LGPL-3.0; a local oracle at most), the Cloudflare Radar bots
  directory (CC BY-NC). From Cloudflare we only read the headers it sets on requests.

## Traps

- `crawler-user-agents` calls "bot" anything that is not a human browser: crawlers, but also test drivers
  (Playwright, Puppeteer, Selenium), scripts (`curl`, `got`) and scanners. Widening `bot?` with it blindly would
  flag the system tests of apps using Agentry: keep the categories apart. `browser_automation` never makes
  `bot?` true; `script/sync_bots.rb` leaves out keywords that would flag a corpus browser (`IGNORED_KEYWORDS`).
- `bots.yml` above its marker line is curated (browser's list), below it is rewritten by `script/sync_bots.rb`:
  edit above, or the next sync drops the change.
- The `*.yml` at the root are the sources; the gem ships and reads `data/*.json`, written from them by
  `ruby script/build_data.rb` (JSON loads about 30 times faster). After editing a `.yml`, run it: `DataTest` fails
  on a stale JSON.
- `lib/browser/testing.rb` reads `test/ua*.yml` at runtime: those fixtures ship in the gem, keep them in
  `s.files`.

## Code style

Follow `STYLE.md` (naming, method size, comments, dead code): what RuboCop can't settle.

## Changelog and releases

- Never edit `CHANGELOG.md` in a PR: any two PRs adding a line there conflict. The changelog is written when
  releasing, from the PRs merged since the last tag; a PR title says what changes for users.
- A draft runs no CI, so it never turns green. Confident in the change: open the pull request ready for review,
  auto-merge on. Not yet: a draft, then `gh pr ready` when it needs the CI.
- To release, read every PR merged since the last tag (`git log --first-parent --oneline <tag>..origin/main`,
  squash merges end in `(#n)`, then `gh pr view n`), and write the release under `## [Unreleased]` without
  committing it: a one-sentence lede, then **Breaking**, **New**, **Faster** (measured, with and without YJIT)
  and **Fixed**, only those with entries. One entry per change users can see, written for them: several PRs may
  make one, CI, refactoring, docs and tests make none. Show it to the user, then `bin/release` commits it with
  the version. No version heading, date or link by hand: `bin/release` writes them.
- `main` takes no direct push, ours included: every change, a release too, goes through a pull request that merges
  itself once the required CI checks are green (`gh pr merge --auto --squash`).
- `bin/release patch|minor|major` cuts a release from a green, up-to-date `main` through such a pull request, then
  tags its merge commit (README, Releasing), and `.github/workflows/release.yml` publishes it. Both are the same in
  every Level UP Solutions gem: change them in all four at once.
- RubyGems trusts the Release workflow (trusted publishing): never `gem push` from a machine.

## Pull requests and issues

- Title: the change as a user sees it (an issue: the finding), in plain words, under 70 characters.
- Body, no headings: two short paragraphs, the problem then the change (an issue: what to do); 3 to 5 bullets,
  each a **bold 2–4 word lead-in** and two lines at most (decisions, divergences, what is left out); the proof
  (reproduction, tests, fuzz seeds, benchmarks) folded in one `<details>`. Nothing the diff or the CI says.
