# Agentry

A fork of [fnando/browser](https://github.com/fnando/browser) (MIT, dormant since June 2025). `gem "agentry"`
replaces `gem "browser"` without touching a call site, but is faster, keeps its bot list fresh and adds signals: bot
categories, verified crawler IPs, Cloudflare headers, Client Hints. The roadmap is in the GitHub issues.

Read `README.md` for usage, `STYLE.md` for code style and `CONTRIBUTING.md` for contributions; this file only
adds what they leave out.

## Commands

```sh
bundle exec rake test                                                        # upstream's suite, unmodified, and ours
bundle exec rubocop
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl # fnando/browser at dd88933
ruby -I lib script/corpus_snapshot.rb > /tmp/agentry.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/agentry.jsonl            # --write records the differences
ruby script/build_data.rb                                                    # data/*.json from the root *.yml
bundle exec rake bench UPSTREAM=path/to/upstream                             # on an idle machine
bundle exec rake docs:render docs:highlight
```

CI also runs `ruby-head`, `jruby-head` and `truffleruby-head`, the corpus diff and the docs checks.

## Traps

- The API stays 1:1 with browser: `Browser.new(ua, accept_language:)`, every predicate and every `require` path keep
  working. New features are additions (`bot.category`), never changed meanings. Upstream's tests stay unmodified;
  new behaviour gets new tests.
- A change not meant to change an answer proves it with the corpus diff over the user agents in `corpus/`. A change
  meant to change answers (a fresher bot list) records the differences it expects in
  `corpus/expected_differences.jsonl` with `--write`.
- The numbers in `docs/*.html` sit between `<!-- render:name -->` markers and come from `docs/*.json`, the bot
  lists and the expected differences. Never type one by hand: CI fails when a page differs from what
  `rake docs:render` writes. A new code block needs `rake docs:highlight`.
- `crawler-user-agents` calls "bot" anything that is not a human browser, including test drivers (Playwright,
  Selenium), scripts (`curl`) and scanners. Keep the categories apart: `browser_automation` never makes `bot?` true,
  or apps using Agentry would flag their own system tests. `script/sync_bots.rb` skips keywords that would flag a
  corpus browser (`IGNORED_KEYWORDS`).
- `bots.yml` is curated above its marker line and rewritten by `script/sync_bots.rb` below it: edit above, or the
  next sync drops your change.
- The `*.yml` at the root are the sources; the gem reads `data/*.json`, built from them. After editing a `.yml`, run
  `script/build_data.rb`: `DataTest` fails on a stale JSON.
- `lib/browser/testing.rb` reads `test/ua*.yml` at runtime, so those fixtures ship in the gem: keep them in
  `s.files`.
- Data sources: only MIT or Apache 2.0 lists (credited in `corpus/SOURCES.md` and the README) and IP ranges the
  crawlers' owners publish. Never embed matomo-org/device-detector (LGPL-3.0) or Cloudflare Radar's bots directory
  (CC BY-NC); from Cloudflare we only read the headers it sets.

## Rules for all our gems

This section and the next two read the same in super-slim, gamba, crumbly and agentry: change all four together.

- Every maintained Ruby and Rails (https://endoflife.date), nothing older. The oldest sets `required_ruby_version`,
  `TargetRubyVersion` and the Rails floor, and leaves in the release after its end of life.
- CI runs RuboCop and the tests on each maintained Ruby. No macOS job: we test on our Macs.
- `.claude/hooks/rubocop.sh` autocorrects each Ruby file you edit.
- Measure performance without JIT and with YJIT. A Performance cop the numbers contradict is disabled on its line,
  with the reason. A pure performance change pins no internals in tests.
- Test and bench data are anonymized: `alice`, `Post`, `example.com`.
- Everything in the repository is in English (code, comments, commits, pull requests, issues, reviews, replies),
  whatever the language of the conversation.
- No AI attribution in anything people read.

## Pull requests and issues

- `main` takes no direct push. Every change, releases included, goes through a pull request that merges itself
  once CI is green: `gh pr merge --auto --squash`.
- Drafts run no CI. Confident in the change? Open it ready for review, auto-merge on. Not yet? Open a draft, then
  `gh pr ready` when it needs CI.
- Never edit `CHANGELOG.md` in a pull request: they would all conflict. It is written at release time.
- Title: the change as a user sees it (for an issue, the finding), in plain words, under 70 characters.
- Body, no headings: two short paragraphs, the problem then the change (for an issue, what to do); 3 to 5 bullets,
  each opening with a **bold 2–4 word lead-in**; the proof (reproduction, tests, benchmarks) folded in one
  `<details>`. Nothing the diff or CI already says.
- Never hard-wrap a pull request, an issue or a comment: GitHub renders every line break. One line per paragraph
  and per bullet.

## Releases

1. List the pull requests merged since the last tag: `git log --first-parent --oneline <tag>..origin/main`, then
   `gh pr view <n>` for each.
2. Write the release under `## [Unreleased]` in `CHANGELOG.md`, uncommitted: a one-sentence lede, then
   **Breaking**, **New**, **Faster** (measured) and **Fixed**, only those with entries. One entry per change users
   can see, written for them; CI, refactoring, docs and tests get none. No version, date or link: `bin/release`
   adds them.
3. Show it to the user. Then `bin/release patch|minor|major` (try `--dry-run` first) commits it through a pull
   request, waits for the merge and tags it; the tag runs `.github/workflows/release.yml`, which publishes the gem.

RubyGems trusts only that workflow: never `gem push` from a machine, except the very first version of a new gem
name. `bin/release` and `release.yml` are the same in all four gems.
