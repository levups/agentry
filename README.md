# Agentry

Agentry reads the `User-Agent` header of an HTTP request and tells you who sent it: the browser and its version,
the operating system, the device, or the bot. It is a Ruby gem, with a helper for Rails controllers and views and a
Rack middleware.

For an iPhone running Safari 18.1, set to French:

```ruby
browser = Browser.new(request.user_agent, accept_language: request.headers["Accept-Language"])

browser.name                       # => "Safari"
browser.version                    # => "18"
browser.platform.name              # => "iOS (iPhone)"
browser.device.mobile?             # => true
browser.bot?                       # => false
browser.accept_language.first.full # => "fr-FR"
```

Site and guide: https://levups.github.io/agentry/

## Where it comes from

Agentry is a fork of [browser](https://github.com/fnando/browser), written by Nando Vieira, which has not changed
since June 2025. It keeps browser's API as it is: the `Browser` class, `require "browser"` and every method below
work the same way, so an app switches by replacing one line of its Gemfile.

On top of that API, Agentry:

- answers faster: 25 µs per request instead of 126 µs with browser 6.2.0, and 2 µs once a user agent has been
  seen (Ruby 4.0.9 with YJIT, `bench/request.rb`);
- updates its bot list every week from [crawler-user-agents](https://github.com/monperrus/crawler-user-agents)
  and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt). Of the 882 crawler user agents added to
  crawler-user-agents since 2024 (test drivers and scanners left out), browser misses 353 and Agentry 11;
- says what kind of bot it is (`bot.category`, `bot.ai?`);
- checks that a request claiming to come from Googlebot, Bingbot, GPTBot or a few others really comes from that
  company's published IP ranges (`bot.verified?(ip)`);
- reads the headers Cloudflare can add about a request, and the Client Hints Chromium sends, which tell Windows 11
  from Windows 10.

## Installation

Add it to your Gemfile:

```ruby
gem "agentry"
```

If the Gemfile has `gem "browser"`, replace that line: the two gems define the same `Browser` class, so Agentry
refuses to load next to browser. Agentry needs Ruby 3.3 or later, and is tested on Rails 8.0 and 8.1.

## Usage

In Rails, every controller and view gets a `browser` helper for the current request:

```erb
<% if browser.bot? %>
  <p>Hello, <%= browser.bot.name %>.</p>
<% end %>
```

Anywhere else, build one from a user agent string. `accept_language:` and `headers:` are optional:

```ruby
browser = Browser.new(user_agent, accept_language: accept_language_header, headers: rack_env)
```

Here is everything you can ask:

```ruby
require "browser"

browser = Browser.new("Some User Agent", accept_language: "en-us")

# General info
browser.bot?
browser.chrome?
browser.chromium_based?
browser.core_media?
browser.duck_duck_go?
browser.edge?                # Newest MS browser
browser.electron?            # Electron Framework
browser.firefox?
browser.full_version
browser.ie?
browser.ie?(6)               # detect specific IE version
browser.ie?([">8", "<10"])   # detect specific IE (IE9).
browser.known?               # has the browser been successfully detected?
browser.unknown?             # the browser wasn't detected.
browser.meta                 # an array with several attributes
browser.name                 # readable browser name
browser.nokia?
browser.opera?
browser.opera_mini?
browser.phantom_js?
browser.quicktime?
browser.safari?
browser.safari_webapp_mode?
browser.samsung_browser?
browser.to_s            # the meta info joined by space
browser.uc_browser?
browser.version         # major version number
browser.webkit?
browser.webkit_full_version
browser.yandex?
browser.wechat?
browser.qq?
browser.weibo?
browser.sputnik?
browser.sougou_browser?
browser.epiphany?

# Get bot info
browser.bot.name
browser.bot.search_engine?
browser.bot.category        # :ai_crawler, :search_engine_crawler, :scanner… (nil for a browser)
browser.bot.ai?
browser.bot.user_triggered? # an AI agent acting for a person right now (ChatGPT-User, Claude-User)
browser.bot?
browser.bot.why? # shows which matcher detected this user agent as a bot.
Browser::Bot.why?(ua)

# Get device info
browser.device
browser.device.id
browser.device.name
browser.device.unknown?
browser.device.blackberry_playbook?
browser.device.console?
browser.device.ipad?
browser.device.iphone?
browser.device.ipod_touch?
browser.device.kindle?
browser.device.kindle_fire?
browser.device.mobile?
browser.device.nintendo?
browser.device.playstation?
browser.device.ps3?
browser.device.ps4?
browser.device.psp?
browser.device.silk?
browser.device.surface?
browser.device.tablet?
browser.device.tv?
browser.device.vita?
browser.device.wii?
browser.device.wiiu?
browser.device.samsung?
browser.device.switch?
browser.device.xbox?
browser.device.xbox_360?
browser.device.xbox_one?

# Get platform info
browser.platform
browser.platform.id
browser.platform.name
browser.platform.version  # e.g. 9 (for iOS9)
browser.platform.adobe_air?
browser.platform.android?
browser.platform.android?(4.2)   # detect Android Jelly Bean 4.2
browser.platform.android_app?     # detect webview in an Android app
browser.platform.android_webview? # alias for android_app?
browser.platform.blackberry?
browser.platform.blackberry?(10) # detect specific BlackBerry version
browser.platform.chrome_os?
browser.platform.firefox_os?
browser.platform.ios?     # detect iOS
browser.platform.ios?(9)  # detect specific iOS version
browser.platform.ios_app?     # detect webview in an iOS app
browser.platform.ios_webview? # alias for ios_app?
browser.platform.linux?
browser.platform.mac?
browser.platform.unknown?
browser.platform.windows10?
browser.platform.windows7?
browser.platform.windows8?
browser.platform.windows8_1?
browser.platform.windows?
browser.platform.windows_mobile?
browser.platform.windows_phone?
browser.platform.windows_rt?
browser.platform.windows_touchscreen_desktop?
browser.platform.windows_vista?
browser.platform.windows_wow64?
browser.platform.windows_x64?
browser.platform.windows_x64_inclusive?
browser.platform.windows_xp?
browser.platform.kai_os?
```

The lists of what is detected live in [lib/browser/platform.rb](lib/browser/platform.rb),
[lib/browser/device.rb](lib/browser/device.rb) and [bots.yml](bots.yml).

### Aliases

`require "browser/aliases"` adds shortcuts such as `browser.mobile?` and `browser.tablet?` to the browser object:

```ruby
require "browser/aliases"
Browser::Base.include(Browser::Aliases)

browser = Browser.new("Some user agent")
browser.mobile? #=> false
```

### Modern browsers

Agentry has no built-in notion of a modern browser: write one with your own version constraints. For example:

```ruby
# Expects a Browser instance,
# like in `Browser.new(user_agent, accept_language: language)`.
def modern_browser?(browser)
  [
    browser.chrome?(">= 65"),
    browser.safari?(">= 10"),
    browser.firefox?(">= 52"),
    browser.ie?(">= 11") && !browser.compatibility_view?,
    browser.edge?(">= 15"),
    browser.opera?(">= 50"),
    browser.facebook?
      && browser.safari_webapp_mode?
      && browser.webkit_full_version.to_i >= 602
  ].any?
end
```

### Rails

The gem adds the `browser` helper to every controller and view on its own:

```erb
<% if browser.ie?(6) %>
  <p class="disclaimer">You're running an older IE version. Please update it!</p>
<% end %>
```

To use Agentry in a Rails app without that helper, require only the library:

```ruby
gem "agentry", require: "browser/browser"
```

### Accept-Language

`browser.accept_language` parses the `Accept-Language` header into the languages the visitor accepts, most
wanted first:

```ruby
browser = Browser.new("Some User Agent", accept_language: "en-us")

browser.accept_language.class
#=> Array

language = browser.accept_language.first

language.code
#=> "en"

language.region
#=> "US"

language.full
#=> "en-US"

language.quality
#=> 1.0

language.name
#=> "English/United States"
```

As the HTTP spec says, a language without a quality value has 1.0, and one with a quality of 0 is not accepted,
so it is left out.

### Internet Explorer

Internet Explorer 8 and later have a compatibility view, in which they report an older version. Agentry returns
the browser's own version and ignores the compatibility view; `Browser#msie_version` and
`Browser#msie_full_version` give the version the engine reports. With compatibility view on in IE11:

```ruby
browser.version
#=> 11

browser.full_version
#=> 11.0

browser.msie_version
#=> 7

browser.msie_full_version
#=> 7.0

browser.compatibility_view?
#=> true
```

browser 1.0.0 introduced this; before it, there was no way to get the real version.

### Safari

An iOS web view, or a site saved to the home screen, is not Safari. Combine the platform and WebKit checks to
find them:

```ruby
# iPad's Safari running as web app mode.
browser = Browser.new("Mozilla/5.0 (iPad; U; CPU OS 3_2_1 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Mobile/7B405")

browser.safari?
#=> false

browser.webkit?
#=> true

browser.platform.ios?
#=> true
```

## Bots

`browser.bot?` is true for:

- an empty user agent;
- a user agent matching `/crawl|fetch|search|monitoring|spider|bot/`;
- a user agent containing one of the keywords of [bots.yml](bots.yml).

The net is wide, as it was in browser.

```ruby
browser = Browser.new("Mozilla/5.0 (compatible; GPTBot/1.2; +https://openai.com/gptbot)")

browser.bot?          # => true
browser.bot.name      # => "ChatGPT"
browser.bot.category  # => :ai_crawler
browser.bot.ai?       # => true
```

Every Monday, a workflow runs `script/sync_bots.rb`, which adds the bots of
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) and
[ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (both MIT) to the end of `bots.yml` and files them
under a category in `bot_categories.yml`. It opens a pull request listing every answer that changes, and a
maintainer merges it. The [Bots page](https://levups.github.io/agentry/bots.html#coverage) counts, per category,
how many of those lists' bots browser and Agentry detect.

### Categories

`browser.bot.category` is what the bot says it is. The names follow Cloudflare's verified bot categories where
one fits (`search_engine_crawler`, `ai_crawler`, `ai_search`, `ai_assistant`, `page_preview`, `feed_fetcher`,
`monitoring_and_analytics`, `advertising_and_marketing`, `archiver`, `security`…), plus `ai_agent`,
`http_library`, `scanner` and `browser_automation`. `bot.ai?` is true for the four AI categories, and
`bot.user_triggered?` for `ai_assistant` and `ai_agent`, the ones a person is driving at that moment
(ChatGPT-User, Claude-User). The category is `nil` for a browser, for a bot exception, and for a bot no list
names.

HTTP libraries (`curl`, `got`, `python-requests`) and scanners (sqlmap, Nikto, Censys) count as bots, as `curl`
and `python-requests` already did in browser. Test drivers (headless Chrome, Playwright, Puppeteer, Selenium) do
not: your own system tests drive a real browser through them, and the headless Chrome of Playwright and Selenium
sends `HeadlessChrome`. They get the `browser_automation` category, so production code can still spot them with
`browser.bot? || browser.bot.category == :browser_automation`. PhantomJS stays a bot, as in browser.

### Your own rules

A matcher is anything that responds to `call(ua, browser)`. This one flags every user agent containing
`externalhit`, under the name `Generic Bot`:

```ruby
Browser::Bot.matchers << ->(ua, _browser) { ua.match?(/externalhit/i) }
```

`Browser::Bot.matchers.clear` removes every matcher, the built-in ones included, and this puts the built-in ones
back:

```ruby
Browser::Bot.matchers += Browser::Bot.default_matchers
```

To get the bot detection of browser 2.x back, remove two matchers:

```ruby
Browser::Bot.matchers.delete(Browser::Bot::KeywordMatcher)
Browser::Bot.matchers.delete(Browser::Bot::EmptyUserAgentMatcher)
```

The lists themselves can be changed at runtime:

```ruby
Browser::Bot.bots.merge!(new_bots_hash)
Browser::Bot.bot_exceptions += new_exceptions
Browser::Bot.search_engines.merge!(new_search_engines_hash)
Browser::Bot.category_by_keyword["faraday"] = :http_library
```

### Verified crawlers

Anyone can send `Googlebot` as their user agent. Google, Bing, OpenAI, Apple, Perplexity and DuckDuckGo publish
the IP ranges their crawlers use, and Agentry ships them, refreshed by the weekly sync
(`script/sync_ip_ranges.rb`). `bot.verified?(ip)` says whether a request comes from the ranges of the company its
user agent names. The check is a binary search in memory, with no network call, and an IP that does not parse
answers `false`.

```ruby
browser.bot.owner                                            # => :google for a user agent claiming Googlebot
browser.bot.verified?(request.remote_ip)                     # => whether the IP is in Google's ranges
browser.bot.verified?(request.remote_ip, reverse_dns: true)  # also Google's DNS check: two DNS queries
Browser::Bot::IPRanges.refresh                               # fetches the ranges again, in a long-lived process
```

Pass the IP as your proxies resolve it: `request.remote_ip` in Rails, with `trusted_proxies` set.

`reverse_dns: true` costs two DNS queries for an IP outside the ranges. The IP's owner controls its reverse DNS,
so a fake Googlebot can make that lookup wait `dns_timeout` (1 second) per nameserver of `/etc/resolv.conf`. A
cache, off by default, remembers each answer, failures included:

```ruby
Browser::Bot::IPRanges.dns_cache_size = 10_000 # 0, the default, caches nothing
Browser::Bot::IPRanges.dns_cache_ttl = 3600    # seconds
Browser::Bot::IPRanges.dns_timeout = 0.5       # seconds per query and nameserver
```

## Cloudflare and Client Hints

Pass the Rack env as `headers:` (the Rails helper and the middleware do it for you) and Agentry reads two more
sources:

- `browser.cloudflare` reads the headers a Cloudflare Transform Rule sets (`verified_bot?`, `bot_category`,
  `bot_score`) and `CF-IPCountry` (`country`). Their names can be changed with
  `Browser::Cloudflare.header_names = {bot_score: "X-My-Score"}`.
- Chromium's Client Hints (`Sec-CH-UA`, `Sec-CH-UA-Mobile`, `Sec-CH-UA-Platform`, `Sec-CH-UA-Platform-Version`)
  refine the platform and the device. `browser.platform.windows11?` needs them.

These headers prove something only when every request goes through Cloudflare: if clients can reach your server
directly, they can send the headers themselves. The rule to create, and how to lock the origin, are in the
[guide](https://levups.github.io/agentry/guide.html#cloudflare). Without `headers:`, every answer comes from the
user agent alone, as in browser. `bench/signals.rb` measures what reading them costs.

## Middleware

`Browser::Middleware` redirects requests based on the browser:

```ruby
use Browser::Middleware do
  redirect_to "/upgrade" if browser.ie?
end
```

In Rails, route helpers work too. In an initializer such as `config/initializers/browser.rb`:

```ruby
Rails.configuration.middleware.use Browser::Middleware do
  redirect_to upgrade_path if browser.ie?
end
```

`request` is the `Rack::Request`, for instance to leave a path alone:

```ruby
Rails.configuration.middleware.use Browser::Middleware do
  redirect_to upgrade_path if browser.ie? && request.env["PATH_INFO"] != "/exclude_me"
end
```

## Limits and cache

A user agent or an `Accept-Language` header longer than 2048 bytes raises `Browser::Error`. Both limits can be
raised:

```ruby
Browser.user_agent_size_limit = 4096
Browser.accept_language_size_limit = 4096
```

Each process remembers what it found for the last 1,000 user agents (browser, platform, device, bot answers) and
the last 1,000 `Accept-Language` headers, about 1 KB per user agent: a user agent seen before costs about 2 µs.
The cache empties itself when it is full, and when `Browser.matchers`, `Browser::Bot.matchers`,
`Browser::Platform.matchers`, `Browser::Device.matchers`, the bot list or its exceptions change. Setting
`Browser.cache_size` empties it too, for example after renaming an entry of `Browser::Bot.bots` in place.

```ruby
Browser.cache_size = 5_000 # 0 turns it off
```

The lists and matchers are built on first use: the first request of each process takes about 13 ms more, the
following ones 0.2 ms. `Browser.eager_load!` builds them at boot, so that a server that loads the app before
forking (Puma's `preload_app!`, Unicorn, Pitchfork) shares them with every worker. Rails calls it whenever it
eager loads, which production does by default. Elsewhere, call it before the fork:

```ruby
Browser.eager_load!
```

## Migrating from browser

Replace `gem "browser"` with `gem "agentry"` in the Gemfile. Nothing else in the code changes.

Some answers do change from the day you switch, because of the fresher bot list: 600 user agents of the corpus
that browser took for people are bots in Agentry, so analytics that leave bots out will count fewer visitors, and
792 user agents that browser called `Generic Bot` get a real name. No browser, platform or device answer changes,
and test drivers still are not bots.

To go back, remove the calls to what browser does not have (`Browser.cache_size=`, the `headers:` argument,
`bot.category`, `bot.ai?`, `bot.user_triggered?`, `bot.verified?`, `browser.cloudflare`), then put `gem "browser"` back. The
[migration guide](https://levups.github.io/agentry/guide.html#migrating) has the details.

## Performance

`bench/request.rb` replays what a web request asks (name, version, `bot?`, platform, device, accept-language)
over 2,000 distinct user agents of the corpus and over 20 repeated ones, and keeps the median of 7 runs. On Ruby
4.0.9 with YJIT, browser 6.2.0 takes 126 µs and 245 objects per request. Agentry takes 25 µs and 52 objects for a
new user agent, and 2 µs and 12 objects for one it has seen. The
[benchmarks page](https://levups.github.io/agentry/benchmarks.html) has all four runs, with and without YJIT.

```bash
bundle exec rake bench UPSTREAM=path/to/upstream # fnando/browser at dd88933
```

It runs `ruby [--yjit] -I lib bench/request.rb --write` for each gem and JIT setting, and records each run (gem,
commit, Ruby, YJIT, machine, date) in `docs/benchmarks.json`. `rake docs:render` then rewrites the site's numbers
from that file.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

The repository holds a corpus of 20,000 user agents. A change that should not change any answer has to prove it,
by comparing every answer with those of [fnando/browser](https://github.com/fnando/browser) at `dd88933`, as CI
does on every pull request:

```bash
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl
ruby -I lib script/corpus_snapshot.rb > /tmp/agentry.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/agentry.jsonl
```

The comparison passes when the answers that differ are exactly those listed in
`corpus/expected_differences.jsonl`. A change meant to change answers rewrites that file with
`ruby script/corpus_diff.rb --write …`, and its diff shows what changed.

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
when a page differs from what `bundle exec rake docs:render` writes.

To add a bot, add its user agent to `test/ua_bots.yml`, and its name to `bots.yml` above the synced section, under
a lowercase string its user agent contains. A search engine goes in `test/ua_search_engines.yml`,
`test/ua_bots.yml` and `search_engines.yml`.

### Releasing

Pull requests leave `CHANGELOG.md` alone. A release starts by writing its notes under `## [Unreleased]`, from the
pull requests merged since the last tag, without committing them. Then, from an up-to-date `main` with green CI:

```sh
bin/release minor --dry-run   # the notes and the changes, nothing written
bin/release minor             # or patch, major, or an exact version such as 1.2.0
```

`main` takes no direct push, so `bin/release` dates the Unreleased section and bumps the version on a branch
`release/vX.Y.Z`, opens its pull request, which merges itself once CI is green, and waits for it. It then pushes a
signed tag `vX.Y.Z` on the merge commit (`bin/release --tag X.Y.Z` does it if you stopped waiting). The tag starts
the Release workflow. It checks that the tag is signed and on `main`, then publishes the gem to RubyGems through
trusted publishing and creates the GitHub release with the version's notes and the `.gem`.

## License

MIT, by Level UP Solutions, see [LICENSE.md](LICENSE.md). Originally written by Nando Vieira as
[fnando/browser](https://github.com/fnando/browser) (MIT). The corpus gathers user agents from
[ua-parser/uap-core](https://github.com/ua-parser/uap-core) (Apache 2.0),
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT) and browser's test fixtures. The bot
list and its categories come from [crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT)
and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (MIT). The crawler IP ranges are the ones
their owners publish for that purpose. [corpus/SOURCES.md](corpus/SOURCES.md) lists every source.
