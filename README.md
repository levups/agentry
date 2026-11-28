# Agentry

Agentry is a Ruby gem that tells you who sent an HTTP request: which browser and version, on which operating system
and device, or which bot. It reads the `User-Agent` header, a line of text every browser and crawler sends with each
request, such as `Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) … Version/18.1 Mobile/15E148
Safari/604.1`. Each browser and crawler writes it in its own way, and Agentry knows the formats so that your code
can ask plain questions such as `agentry.bot?` or `agentry.device.mobile?`.

Apps use the answers to leave bots out of their analytics, to turn crawlers away, to adapt a page to phones, or to
warn visitors on an old browser. Agentry works in any Ruby program, and gives Rails controllers and views an
`agentry` helper for the current request.

Website and guide: https://levups.github.io/agentry/

Coding agents can start from <https://levups.github.io/agentry/llms.txt>, or read this README and the
website's pages as one Markdown file: <https://levups.github.io/agentry/llms-full.txt>.

## Why Agentry

Agentry is a fork of [browser](https://github.com/fnando/browser), the gem Nando Vieira wrote, which has not changed
since June 2025. It has the same methods under its own name, `Agentry` instead of `Browser`, and Agentry 4 still
answers to the old names, so code written for browser runs on it as it is (see
[Switching from browser](#switching-from-browser)). Here is what is different:

- It answers in 25 µs per request instead of 126 µs with browser 6.2.0, and in 2 µs for a user agent the process
  has seen before (Ruby 4.0.9 with YJIT, see [Performance](#performance)).
- Its list of bots is updated every week. Of the 882 crawler user agents added to
  [crawler-user-agents](https://github.com/monperrus/crawler-user-agents) since 2024 (test drivers and scanners
  left out), browser misses 353 and Agentry 11.
- It says what kind of bot sent the request: an AI crawler, a search engine, an assistant fetching a page for a
  person, a vulnerability scanner.
- It can check that a request claiming to be Googlebot, Bingbot or GPTBot comes from the IP addresses Google,
  Microsoft or OpenAI publish for their crawlers.
- It reads the headers Cloudflare can add to a request, and the Client Hints Chromium browsers send, which tell
  Windows 11 from Windows 10.

## Installation

Agentry needs Ruby 3.3 or later. It is tested on Rails 8.0 and 8.1, and works without Rails. Add it to your Gemfile:

```ruby
gem "agentry"
```

If the Gemfile already has `gem "browser"`, see [Switching from browser](#switching-from-browser).

## A first example

```ruby
require "agentry"

user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 " \
             "(KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1"
agentry = Agentry.new(user_agent, accept_language: "fr-FR,fr;q=0.9,en;q=0.8")

agentry.name                       # => "Safari"
agentry.version                    # => "18"
agentry.full_version               # => "18.1"
agentry.platform.name              # => "iOS (iPhone)"
agentry.device.mobile?             # => true
agentry.bot?                       # => false
agentry.accept_language.first.full # => "fr-FR"
```

`accept_language:` is optional: it takes the `Accept-Language` header, the languages the visitor's browser asks
for.

In Rails there is nothing to build. The `agentry` helper reads the current request's headers:

```erb
<% if agentry.device.mobile? %>
  <%= render "mobile_menu" %>
<% end %>
```

Outside Rails, pass the Rack env as `headers:` so that Agentry can read Client Hints and Cloudflare headers too:
`Agentry.new(user_agent, accept_language: language, headers: env)`.

The [guide](https://levups.github.io/agentry/guide.html#usage) lists every method: browsers from Chrome and Safari
to WeChat and Yandex, devices such as the iPad, Kindle, PlayStation and Xbox, and platforms down to each version of
Windows. Version checks take a number or constraints, such as `agentry.chrome?(">= 65")` or
`agentry.platform.ios?(9)`.

## Bots

```ruby
agentry = Agentry.new("Mozilla/5.0 (compatible; GPTBot/1.2; +https://openai.com/gptbot)")

agentry.bot?                # => true
agentry.bot.name            # => "ChatGPT"
agentry.bot.category        # => :ai_crawler
agentry.bot.ai?             # => true
agentry.bot.user_triggered? # => false
```

`agentry.bot?` is true for an empty user agent, for one that matches `/crawl|fetch|search|monitoring|spider|bot/`,
and for one that contains a name from [bots.yml](bots.yml). The net is wide on purpose, as it was in browser.

Every Monday, a workflow adds the bots of [crawler-user-agents](https://github.com/monperrus/crawler-user-agents)
and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (both MIT) to `bots.yml` and files each under a
category. It opens a pull request that lists every answer the change moves, and a maintainer merges it. The
[Bots page](https://levups.github.io/agentry/bots.html#coverage) counts, per category, how many of those bots
browser and Agentry detect.

### Categories

`agentry.bot.category` is what the bot says it is, named after Cloudflare's verified bot categories where one fits:
`search_engine_crawler`, `ai_crawler`, `ai_search`, `ai_assistant`, `page_preview`, `feed_fetcher`,
`monitoring_and_analytics`, `advertising_and_marketing`, `archiver`, `security` and a few more. Agentry adds
`ai_agent`, `http_library`, `scanner` and `browser_automation`. `bot.ai?` is true for the four AI categories, and
`bot.user_triggered?` for `ai_assistant` and `ai_agent`: a person is driving them at that moment, as with
ChatGPT-User or Claude-User. The category is `nil` for a browser, for a bot exception, and for a bot no list names.

HTTP libraries (`curl`, `python-requests`) and scanners (sqlmap, Nikto) are bots. Test drivers (headless Chrome,
Playwright, Puppeteer, Selenium) are not: your own system tests drive a real browser through them, and would
otherwise count as bots. They get the `browser_automation` category, so production code can still catch them with
`agentry.bot? || agentry.bot.category == :browser_automation`. PhantomJS stays a bot, as in browser.

### Your own rules

A matcher is anything that responds to `call(ua, browser)`. This one makes every user agent containing
`externalhit` a bot:

```ruby
Agentry::Bot.matchers << ->(ua, _browser) { ua.match?(/externalhit/i) }
```

`agentry.bot.why?` returns the matcher that fired. The lists can change at runtime too
(`Agentry::Bot.bots.merge!(new_bots_hash)`), and the
[Bots page](https://levups.github.io/agentry/bots.html#matchers) shows how to remove the built-in matchers or go
back to the detection of browser 2.x.

### Verified crawlers

Anyone can send `Googlebot` as their user agent. Google, Bing, OpenAI, Apple, Perplexity and DuckDuckGo publish the
IP ranges their crawlers use, and Agentry ships them, refreshed by the weekly sync. `bot.verified?(ip)` says whether
a request comes from the ranges of the company its user agent names:

```ruby
agentry.bot.owner                        # => :google for a user agent claiming to be Googlebot
agentry.bot.verified?(request.remote_ip) # => true when the IP is in Google's ranges

if agentry.bot.owner && !agentry.bot.verified?(request.remote_ip)
  head :forbidden # claims to be a known crawler, comes from somewhere else
end
```

The check searches the ranges in memory, with no network call, and an IP that does not parse answers `false`. Pass
the IP as your proxies resolve it: `request.remote_ip` in Rails, with `trusted_proxies` set.

`verified?(ip, reverse_dns: true)` adds the DNS check Google, Bing and Apple document, at the cost of two DNS
queries for an IP outside the ranges. A fake Googlebot controls its own reverse DNS and can make that lookup wait
for the timeout (1 second per nameserver of `/etc/resolv.conf`), so a cache, off by default, can remember each
answer, failures included:

```ruby
Agentry::Bot::IPRanges.dns_cache_size = 10_000 # 0, the default, caches nothing
Agentry::Bot::IPRanges.dns_cache_ttl = 3600    # seconds
Agentry::Bot::IPRanges.dns_timeout = 0.5       # seconds per query and nameserver
Agentry::Bot::IPRanges.refresh                 # fetches the ranges again, in a long-lived process
```

The reverse lookup reads answers from a name server the requester chooses, and versions of the `resolv` gem before
0.7.2 (0.3.2 in the 0.3 series) can be made to use up memory or CPU by such answers (CVE-2026-80212,
CVE-2025-24294). Before turning `reverse_dns:` on, check `bundle info resolv`, or add `gem "resolv", ">= 0.7.2"`
to your Gemfile.

## Cloudflare and Client Hints

When the Rack env is passed as `headers:` (the Rails helper and the middleware do it for you), Agentry reads two
more sources.

Behind Cloudflare, a Transform Rule can copy what Cloudflare knows about a request into headers, and
`agentry.cloudflare` reads them:

```ruby
agentry.cloudflare.verified_bot? # => true for a bot Cloudflare verified
agentry.cloudflare.bot_category  # => :search_engine_crawler, with the names of bot.category
agentry.cloudflare.bot_score     # => 1 (automated) to 99 (human), with Bot Management only
agentry.cloudflare.country       # => "FR", from CF-IPCountry
```

The header names can be changed with `Agentry::Cloudflare.header_names = {bot_score: "X-My-Score"}`. These headers
prove something only when every request goes through Cloudflare: if clients can reach your server directly, they
can send the headers themselves. The [guide](https://levups.github.io/agentry/guide.html#cloudflare) has the rule to
create and how to lock the origin.

Chromium browsers no longer put the real Windows, macOS or Android version in their user agent. They send it in
Client Hints (`Sec-CH-UA`, `Sec-CH-UA-Mobile`, `Sec-CH-UA-Platform`, `Sec-CH-UA-Platform-Version`), which Agentry
uses to refine the platform and the device: `agentry.platform.windows11?` needs them. Without `headers:`, every
answer comes from the user agent alone, as in browser. The
[guide](https://levups.github.io/agentry/guide.html#client-hints) shows how to ask browsers for the platform
version. `bench/signals.rb` measures what reading these headers costs.

## Accept-Language

`agentry.accept_language` turns the `Accept-Language` header into a list of languages, the most wanted first:

```ruby
language = Agentry.new(user_agent, accept_language: "en-us").accept_language.first

language.code    # => "en"
language.region  # => "US"
language.full    # => "en-US"
language.quality # => 1.0
language.name    # => "English/United States"
```

As the HTTP specification says, a language without a quality value has 1.0, and one with a quality of 0 is not
accepted, so it is left out.

## Middleware

`Agentry::Middleware` redirects requests based on the browser, before they reach your app. In Rails, from an
initializer such as `config/initializers/agentry.rb`, route helpers work and `request` is the `Rack::Request`:

```ruby
Rails.configuration.middleware.use Agentry::Middleware do
  redirect_to upgrade_path if agentry.ie? && request.env["PATH_INFO"] != "/exclude_me"
end
```

In another Rack app, `use Agentry::Middleware do … end` takes the same block. To use Agentry in Rails without the
`agentry` helper, require only the library: `gem "agentry", require: "agentry/agentry"`.

## Cache, limits and boot

Each process remembers what it found for the last 1,000 user agents (browser, platform, device and bot answers),
the last 1,000 `Accept-Language` headers and the last 1,000 sets of Client Hints, about 1 KB per user agent and up
to 6 KB per forged set of hints. A `Sec-CH-UA` naming more than 8 brands is never kept. A user agent seen before
costs about 2 µs.
The cache empties itself when it is full, and when `Agentry.matchers`, `Agentry::Bot.matchers`,
`Agentry::Platform.matchers`, `Agentry::Device.matchers`, the bot list or its exceptions change. Setting
`Agentry.cache_size` empties it too, for example after renaming an entry of `Agentry::Bot.bots`,
`Agentry::Bot.search_engines` or `Agentry::Bot.category_by_keyword` in place, or any change that keeps their size:

```ruby
Agentry.cache_size = 5_000 # 0 turns it off
```

A user agent or an `Accept-Language` header longer than 2048 bytes raises `Agentry::Error`. Both limits can be
raised with `Agentry.user_agent_size_limit = 4096` and `Agentry.accept_language_size_limit = 4096`. An
`Accept-Language` header listing more than 32 languages is parsed on each request instead of cached, so that
crafted headers cannot fill the cache with thousands of languages each.

Headers whose bytes are not valid UTF-8, forged or read back from a log file, do not raise: Agentry reads the user
agent and the `Accept-Language` header with each invalid byte replaced by U+FFFD, and ignores such a Client Hint or
Cloudflare header. Version checks such as `agentry.chrome?(">= 65")` leave the versions they read from a request
out of RubyGems' version cache, where those an attacker sends would pile up for the life of the process.

The lists and matchers are built on first use: the first request of each process takes about 13 ms more, the
following ones 0.2 ms. `Agentry.eager_load!` builds them at boot, so that a server that loads the app before
forking (Puma's `preload_app!`, Unicorn, Pitchfork) shares them with every worker. Rails calls it whenever it eager
loads, which production does by default. Elsewhere, call `Agentry.eager_load!` before the fork.

## Switching from browser

Replace `gem "browser"` with `gem "agentry", require: "browser"` in the Gemfile (keep `require: "browser/browser"`
if the app had it). Code written for browser keeps working on Agentry 4: the require paths browser documents
(`browser`, `browser/browser`, `browser/aliases`) and `browser/testing`, `browser/rails` still load and define
`Browser` as another name for `Agentry`, and the `browser` helper still answers. A bare `gem "agentry"` leaves out
the `Browser` constant, which then raises `NameError`. The old names are deprecated and go away in Agentry 5,
so move to the new ones when you can:

| browser, deprecated in Agentry 4 | Agentry |
|---|---|
| `gem "browser"`, `require "browser"` | `gem "agentry"`, `require "agentry"` |
| `require: "browser/browser"` (without Rails) | `require: "agentry/agentry"` |
| `require "browser/aliases"`, `"browser/testing"`, `"browser/rails"` | `require "agentry/aliases"`, `"agentry/testing"`, `"agentry/rails"` |
| `Browser.new(…)`, `Browser::Bot`, `Browser::Middleware`… | `Agentry.new(…)`, `Agentry::Bot`, `Agentry::Middleware`… |
| the `browser` helper, `browser` in a middleware block | `agentry` |
| `@browser`, in controllers, views, tests and middleware blocks (no warning) | `@agentry` |
| `config.browser` | `config.agentry` |

Each deprecation warns once per process, only where Ruby shows deprecations: run the tests with
`RUBYOPT=-W:deprecated` to list what is left to move. The
[migration guide](https://levups.github.io/agentry/migration.html) walks through the change, and gives a prompt
for a coding agent to make it. Class names change even where code keeps calling `Browser`: `browser.class.name`
reads `Agentry::Chrome`. Agentry 4 ships the same `browser/*` files as the browser gem, so it cannot share a
bundle with it, for example through a dependency that still needs browser; Agentry 5 drops those files.

Some answers change from the day you switch, because of the fresher bot list: 600 user agents of the corpus that
browser took for people are bots in Agentry, so analytics that leave bots out will count fewer visitors, and 792
user agents that browser called `Generic Bot` get a real name. No browser, platform or device answer changes, and
test drivers still are not bots.

To go back, remove the calls to what browser does not have (`cache_size=`, the `headers:` argument,
`bot.category`, `bot.ai?`, `bot.user_triggered?`, `bot.verified?`, `cloudflare`), bring back the browser names of
the table above, then put `gem "browser"` back. The
[migration guide](https://levups.github.io/agentry/migration.html#going-back) has the details.

## Performance

`bench/request.rb` asks what a web request typically asks (name, version, `bot?`, platform, device,
accept-language) over 2,000 distinct user agents of the corpus and over 20 repeated ones, and keeps the median of 7
runs. On Ruby 4.0.9 with YJIT:

| Per request | browser 6.2.0 | Agentry |
|---|---:|---:|
| A new user agent | 126 µs, 245 objects | 25 µs, 52 objects |
| A user agent seen before | 114 µs, 217 objects | 2 µs, 12 objects |

The [benchmarks page](https://levups.github.io/agentry/benchmarks.html) has the runs without YJIT, the machine, and
why Agentry is faster. To run them again:

```bash
bundle exec rake bench UPSTREAM=path/to/upstream # a clone of fnando/browser at dd88933
```

It runs `ruby [--yjit] -I lib bench/request.rb --write` for each gem and JIT setting, records each run (gem,
commit, Ruby, YJIT, machine, date) in `docs/benchmarks.json`, and `rake docs:render` then rewrites the site's
numbers from that file.

## How the answers are checked

Agentry runs browser's own test suite, unmodified (it calls `Browser`, which Agentry 4 still answers to), next to
its own tests. The repository also holds a corpus of 20,328 user agents, gathered from uap-core,
crawler-user-agents and browser's test fixtures. On every pull request, CI asks both browser and Agentry about each of them and compares the answers. An answer that differs is either
listed in `corpus/expected_differences.jsonl` as an intended change, such as a newly known bot, or fails the build.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

To compare every answer with [fnando/browser](https://github.com/fnando/browser) at `dd88933`, as CI does:

```bash
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl
ruby -I lib script/corpus_snapshot.rb > /tmp/agentry.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/agentry.jsonl
```

It passes when the answers that differ are exactly those in `corpus/expected_differences.jsonl`. A change meant to
change answers rewrites that file with `ruby script/corpus_diff.rb --write …`, and its diff shows what changed.

The weekly bot sync (`.github/workflows/bot-sync.yml`) runs these steps, which also work by hand:

```bash
ruby script/sync_bots.rb                         # bots.yml and bot_categories.yml
ruby -I lib script/sync_ip_ranges.rb             # bot_ip_ranges.yml
ruby script/build_data.rb                        # data/*.json, what the gem reads, from the *.yml
ruby script/bot_coverage.rb path/to/upstream/lib # docs/bot_coverage.json, and its Markdown table
ruby script/render_docs.rb                       # the site's numbers, from docs/*.json and the lists
```

The numbers on the site's pages (`docs/*.html`) sit between `<!-- render:… -->` markers and come from
`docs/benchmarks.json`, `docs/bot_coverage.json`, the bot lists and `corpus/expected_differences.jsonl`. CI fails
when a page differs from what `bundle exec rake docs:render` writes. A new code block on a page needs
`bundle exec rake docs:highlight`.

To add a bot, add its user agent to `test/ua_bots.yml`, and its name to `bots.yml` above the synced section, under
a lowercase string its user agent contains. A search engine goes in `test/ua_search_engines.yml`,
`test/ua_bots.yml` and `search_engines.yml`.

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

### Releasing

Pull requests leave `CHANGELOG.md` alone. A release starts by writing its notes under `## [Unreleased]`, from the
pull requests merged since the last tag, without committing them. Then, from an up-to-date `main` with green CI:

```sh
bin/release minor --dry-run   # shows the notes and the changes, writes nothing
bin/release minor             # or patch, major, or an exact version such as 1.2.0
```

`main` takes no direct push, so `bin/release` dates the notes and bumps the version on a `release/vX.Y.Z` branch,
opens a pull request that merges itself once CI is green, and waits for it (`bin/release --wait X.Y.Z` if you
stopped it). The merge starts the Release workflow, which waits for a maintainer's approval, tags the merge commit
`vX.Y.Z`, publishes the gem to RubyGems through trusted publishing and creates the GitHub release with the notes
and the `.gem`.

## License

MIT, by Level UP Solutions, see [LICENSE.md](LICENSE.md). Originally written by Nando Vieira as
[fnando/browser](https://github.com/fnando/browser) (MIT). The corpus gathers user agents from
[ua-parser/uap-core](https://github.com/ua-parser/uap-core) (Apache 2.0),
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT) and browser's test fixtures. The bot
list and its categories come from [crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT)
and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (MIT). The crawler IP ranges are the ones
their owners publish for that purpose. [corpus/SOURCES.md](corpus/SOURCES.md) lists every source.
