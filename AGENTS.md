# Agentry

A fork of [fnando/browser](https://github.com/fnando/browser) (MIT, dormant since June 2025), under its own name
since 4.0: `Agentry`, `require "agentry"`, the `agentry` helper. It is faster, keeps its bot list fresh and adds
signals: bot categories, verified crawler IPs, Cloudflare headers, Client Hints. The roadmap is in the GitHub issues.

`README.md` covers usage, `STYLE.md` code style, `CONTRIBUTING.md` contributions; this file adds what they leave out.

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

- Every predicate keeps browser's meaning; new features are additions (`bot.category`). Until 5.0, browser's names
  still work, deprecated: `lib/browser/*` requires and `lib/agentry/browser_constant.rb` (`Browser = Agentry`), the
  `browser` helper, `browser` in a middleware block, `@browser` (helper and middleware context), `config.browser`.
  `require "agentry"` must never define `Browser`. Agentry 4 cannot share a bundle with the browser gem (same
  `lib/browser*` files). Upstream's tests stay unmodified and call `Browser` through the shim (`test_helper.rb`);
  ours and new tests call `Agentry`.
- `script/corpus_snapshot.rb`, `script/bot_coverage.rb` and `bench/request.rb` run against upstream too, so they
  keep `require "browser"`.
- A change not meant to change an answer proves it with the corpus diff over the user agents in `corpus/`. One meant
  to (a fresher bot list) records the differences it expects in `corpus/expected_differences.jsonl` with `--write`.
- The numbers in `docs/*.html` sit between `<!-- render:name -->` markers and come from `docs/*.json`, the bot lists
  and the expected differences. Never type one: CI fails when a page differs from what `rake docs:render` writes. A
  new code block needs `rake docs:highlight`.
- `crawler-user-agents` calls "bot" anything that is not a human browser, test drivers (Playwright, Selenium),
  scripts (`curl`) and scanners included. Keep the categories apart: `browser_automation` never makes `bot?` true,
  or apps using Agentry would flag their own system tests. `script/sync_bots.rb` skips keywords that would flag a
  corpus browser (`IGNORED_KEYWORDS`).
- `bots.yml` is curated above its marker line and rewritten by `script/sync_bots.rb` below it: edit above, or the
  next sync drops your change.
- The root `*.yml` are the sources; the gem reads `data/*.json`, built from them by `script/build_data.rb`, to run
  after editing a `.yml`: `DataTest` fails on a stale JSON.
- `lib/agentry/testing.rb` reads `test/ua*.yml` at runtime, so those fixtures ship in the gem: keep them in
  `s.files`.
- Data sources: only MIT or Apache 2.0 lists (credited in `corpus/SOURCES.md` and the README) and IP ranges the
  crawlers' owners publish. Never embed matomo-org/device-detector (LGPL-3.0) or Cloudflare Radar's bots directory
  (CC BY-NC); from Cloudflare we only read the headers it sets.

## Rules for all our gems

This section and the next two read the same in super-slim, gamba, crumbly, agentry and maptain: change all five
together.

You are the owner and long-term maintainer of this codebase, and its design is up to you. Its public API is a
promise to its users; everything behind it is yours to reshape when that serves them.

- Every maintained Ruby and Rails (https://endoflife.date), nothing older. The oldest sets `required_ruby_version`,
  `TargetRubyVersion` and the Rails floor, and leaves in the release after its end of life.
- CI runs RuboCop and the tests on each maintained Ruby. No macOS job: we test on our Macs.
- `.claude/hooks/rubocop.sh` autocorrects each Ruby file you edit.
- Measure performance without JIT and with YJIT. A Performance cop the numbers contradict is disabled on its line,
  with the reason. A pure performance change pins no internals in tests.
- Test and bench data are anonymized: `alice`, `Post`, `example.com`.
- `docs/llms.txt` (an index for coding agents) and `docs/llms-full.txt` (the README and
  the pages of `docs/`, in Markdown) come from `bundle exec rake docs:llms`: run it after changing the README or a page of
  `docs/`. CI checks them.
- Everything in the repository is in English (code, comments, commits, pull requests, issues, reviews, replies),
  whatever the conversation's language.
- No AI attribution in anything people read; commits flag AI help with `Assisted-by`, never `Co-Authored-By`.

## Pull requests and issues

- `main` takes no direct push: every change, releases included, goes through a pull request that merges itself once
  CI is green (`gh pr merge --auto --squash`).
- Drafts run no CI. Confident: open it ready, auto-merge on. Not yet: a draft, then `gh pr ready` when it needs CI.
- Never edit `CHANGELOG.md` in a pull request, they would all conflict: it is written at release time.
- Title: the change as a user sees it (an issue: the finding), in plain words, under 70 characters.
- Body, no headings: two short paragraphs, the problem then the change (an issue: what to do); 3 to 5 bullets, each
  opening with a **bold 2–4 word lead-in**; the proof (reproduction, tests, benchmarks) folded in one `<details>`.
  Nothing the diff or CI already says.
- Never hard-wrap a pull request, an issue or a comment: GitHub renders every line break. One line per paragraph and
  per bullet.

## Releases

The user is needed once: one click approving the `release` environment on GitHub. No key, no Mac.

1. Another session may have just released: `git fetch --tags origin`, and `gh pr list --search "head:release/"`
   must be empty. Unreleased changes: `git log --first-parent --oneline $(git describe --tags --abbrev=0 origin/main)..origin/main`,
   then `gh pr view <n>` for each.
2. Write the release under `## [Unreleased]` in `CHANGELOG.md`, uncommitted: a one-sentence lede, then **Breaking**,
   **New**, **Faster** (measured), **Fixed**, only those with entries. One entry per change users see, written for
   them; CI, refactoring, docs and tests get none. No version, date or link: `bin/release` adds them.
3. Show it to the user, wait for their go. From `main` level with `origin/main`, `CHANGELOG.md` its only change:
   `bin/release minor --dry-run`, then `bin/release minor --yes` (or `patch`, `major`). It opens `release/vX.Y.Z`,
   waits for it to merge itself, then opens the release run. Interrupted: `bin/release --wait X.Y.Z`. Where `gh pr`
   can't run, `bin/release minor --write` writes the changes: commit them, open the pull request with auto-merge.
4. The merge runs `release.yml`, which waits for the user to approve the `release` environment, then tags the merge
   commit `vX.Y.Z` and publishes to RubyGems and GitHub. Send them the run's link, where they click Review
   deployments, `release`, Approve (from their phone too). Then check RubyGems. A failed run runs again from its page,
   or with `gh workflow run release.yml`: each step skips what is done.

Only a merged pull request publishes: a version with notes in `CHANGELOG.md` and no tag yet. RubyGems trusts only
that workflow: never `gem push`, except a new gem name's first version, pushed by hand while its run waits for
approval. `bin/release` and `release.yml` are identical in all five gems.
