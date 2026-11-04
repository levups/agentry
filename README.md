# BrowserX

Browser detection for Ruby, with ActionController integration: the API of the
[browser](https://rubygems.org/gems/browser) gem, faster, and a bot list that stays fresh. Put `gem "browserx"` in
your Gemfile instead of `gem "browser"`, and every call site keeps working — same `Browser` namespace, same
`require "browser"`, same predicates.

- **Faster**: 25 µs per request instead of 126 µs with browser 6.2.0, 2 µs once a user agent was seen (Ruby 4.0.9,
  YJIT, `bench/request.rb`).
- **Fresher bots**: synced every week from [crawler-user-agents](https://github.com/monperrus/crawler-user-agents)
  and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt), with categories (`bot.category`, `bot.ai?`).
  Of the 882 crawler user agents added to crawler-user-agents since 2024 (test drivers and scanners left out),
  browser misses 353, BrowserX 11.

Site: https://next-gen-gems.github.io/browserx/

## Installation

```ruby
gem "browserx"
```

## Usage

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

### Aliases

To add aliases like `mobile?` and `tablet?` to the base object (e.g
`browser.mobile?`), require the `browser/aliases` file and extend the
Browser::Base object like the following:

```ruby
require "browser/aliases"
Browser::Base.include(Browser::Aliases)

browser = Browser.new("Some user agent")
browser.mobile? #=> false
```

### What's being detected?

- For a list of platform detections, check
  [lib/browser/platform.rb](lib/browser/platform.rb)
- For a list of device detections, check
  [lib/browser/device.rb](lib/browser/device.rb)
- For a list of bot detections, check
  [bots.yml](bots.yml)

### Detecting modern browsers

To detect whether a browser can be considered as modern or not, create a method
that abstracts your versioning constraints. The following example will consider
any of the following browsers as a modern:

```ruby
# Expects an Browser instance,
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

### Migrating from browser

Replace `gem "browser"` with `gem "browserx"` in the Gemfile, nothing else: `require "browser"`, the `Browser`
namespace and every predicate stay. Both gems define `Browser`, so BrowserX refuses to load next to `browser`,
with an error saying so, rather than letting one silently override the other. BrowserX requires Ruby 3.3 or later
and is tested on Rails 8.0 and 8.1.

What changes on its own: the bots of the weekly sync are bots from the day you switch (600 user agents of the
corpus that browser took for humans), so analytics that leave bots out count fewer visitors from that day; 792
user agents named `Generic Bot` get a name; no browser, platform or device answer moves, and test drivers stay out
of `bot?`. To roll back, put `gem "browser"` back, after removing the calls to what browser lacks
(`Browser.cache_size=`, `bot.category`, `bot.ai?`, `bot.user_triggered?`). The
[migration guide](https://next-gen-gems.github.io/browserx/guide.html#migrating) has the details.

### Rails integration

Just add it to the Gemfile.

```ruby
gem "browserx"
```

This adds a helper method called `browser`, that inspects your current user
agent.

```erb
<% if browser.ie?(6) %>
  <p class="disclaimer">You're running an older IE version. Please update it!</p>
<% end %>
```

If you want to use Browser on your Rails app but don't want to taint your
controller, use the following line on your Gemfile:

```ruby
gem "browserx", require: "browser/browser"
```

### Accept Language

Parses the accept-language header from an HTTP request and produces an array of
language objects sorted by quality.

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

Result is always sorted in quality order from highest to lowest. As per the HTTP
spec:

- omitting the quality value implies 1.0.
- quality value equal to zero means that is not accepted by the client.

### Internet Explorer

Internet Explorer has a compatibility view mode that allows newer versions
(IE8+) to run as an older version. Browser will always return the navigator
version, ignoring the compatibility view version, when defined. If you need to
get the engine's version, you have to use `Browser#msie_version` and
`Browser#msie_full_version`.

So, let's say an user activates compatibility view in a IE11 browser. This is
what you'll get:

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

This behavior changed in browser v1.0.0; previously there wasn't a way of getting the
real browser version.

### Safari

iOS webviews and web apps aren't detected as Safari anymore, so be aware of that
if that's your case. You can use a combination of platform and webkit detection
to do whatever you want.

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

### Bots

The bot detection is quite aggressive. Anything that matches at least one of the
following requirements will be considered a bot.

- Empty user agent string
- User agent that matches `/crawl|fetch|search|monitoring|spider|bot/`
- Any known bot listed under
  [bots.yml](bots.yml)

Every week, `script/sync_bots.rb` adds the bots of
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) and
[ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (both MIT) to the end of `bots.yml`, and
categorizes them in `bot_categories.yml`, through a pull request that lists the answers that change. How many of
those lists' bots browser and BrowserX detect, per category, is on the
[Bots page](https://next-gen-gems.github.io/browserx/bots.html#coverage).

`browser.bot.category` names what the bot declares it is, with the names of Cloudflare's verified bot categories
where one fits (`search_engine_crawler`, `ai_crawler`, `ai_search`, `ai_assistant`, `page_preview`,
`feed_fetcher`, `monitoring_and_analytics`, `advertising_and_marketing`, `archiver`, `security`…), plus
`ai_agent`, `http_library`, `scanner` and `browser_automation`. `bot.ai?` is true for the four AI categories,
`bot.user_triggered?` for `ai_assistant` and `ai_agent`. The category is `nil` for a browser, a bot exception
and a bot no list names.

HTTP libraries (`curl`, `got`, `python-requests`) and scanners (sqlmap, Nikto, Censys) are bots, as `curl` and
`python-requests` already were in browser. Test drivers (headless Chrome, Playwright, Puppeteer, Selenium) are
not: an app's system tests drive a real browser through them, and the headless Chrome of Playwright and Selenium
sends `HeadlessChrome`. They get the `browser_automation` category instead, so an app can tell them apart in
production (`browser.bot? || browser.bot.category == :browser_automation`). PhantomJS stays a bot, as in
browser.

To add custom matchers, you can add a callable object to
`Browser::Bot.matchers`. The following example matches everything that has a
`externalhit` substring on it. The bot name will always be `General Bot`.

```ruby
Browser::Bot.matchers << ->(ua, _browser) { ua.match?(/externalhit/i) }
```

To clear all matchers, including the ones that are bundled, use
`Browser::Bot.matchers.clear`. You can re-add built-in matchers by doing the
following:

```ruby
Browser::Bot.matchers += Browser::Bot.default_matchers
```

To restore v2's bot detection, remove the following matchers:

```ruby
Browser::Bot.matchers.delete(Browser::Bot::KeywordMatcher)
Browser::Bot.matchers.delete(Browser::Bot::EmptyUserAgentMatcher)
```

To extend the bot list, you can manipulate the methods below:

```ruby
Browser::Bot.bots.merge!(new_bots_hash)
Browser::Bot.bot_exceptions += new_exceptions
Browser::Bot.search_engines.merge!(new_search_engines_hash)
Browser::Bot.category_by_keyword["faraday"] = :http_library
```

### Middleware

You can use the `Browser::Middleware` to redirect user agents.

```ruby
use Browser::Middleware do
  redirect_to "/upgrade" if browser.ie?
end
```

If you're using Rails, you can use the route helper methods. Just add something
like the following to a initializer file (`config/initializers/browser.rb`).

```ruby
Rails.configuration.middleware.use Browser::Middleware do
  redirect_to upgrade_path if browser.ie?
end
```

If you need access to the `Rack::Request` object (e.g. to exclude a path), you
can do so with `request`.

```ruby
Rails.configuration.middleware.use Browser::Middleware do
  redirect_to upgrade_path if browser.ie? && request.env["PATH_INFO"] != "/exclude_me"
end
```

### Restrictions

- User agent has a size limit of 2048 bytes. This can be customized through
  `Browser.user_agent_size_limit=(size)`.
- Accept-Language has a size limit of 2048 bytes. This can be customized through
  `Browser.accept_language_size_limit=(size)`.

If size is not respected, then `Browser::Error` is raised.

```ruby
Browser.user_agent_size_limit = 4096
Browser.accept_language_size_limit = 4096
```

### Cache

Each process keeps what it detected for the last 1,000 distinct user agents (browser, platform, device, bot
answers) and the last 1,000 Accept-Language headers it parsed, about 1 KB per user agent: a repeated user agent
costs about 2 µs. The cache empties itself when full, and when `Browser.matchers`, `Browser::Bot.matchers`,
`Browser::Platform.matchers`, `Browser::Device.matchers`, the bot list or its exceptions change. Setting
`Browser.cache_size` empties it too, for example after renaming an entry of `Browser::Bot.bots` in place.

```ruby
Browser.cache_size = 5_000 # 0 turns it off
```

## Performance

`bench/request.rb` replays what a web request asks (name, version, `bot?`, platform, device, accept-language) over
2,000 distinct user agents of the corpus and over 20 repeated ones, median of 7. On Ruby 4.0.9 with YJIT, browser
6.2.0 takes 126 µs and 245 objects per request, BrowserX 25 µs and 52 objects on a new user agent, 2 µs and 12
objects on a repeated one. All four runs, with and without YJIT, are on the
[benchmarks page](https://next-gen-gems.github.io/browserx/benchmarks.html).

```bash
bundle exec rake bench UPSTREAM=path/to/upstream # fnando/browser at dd88933
```

It runs `ruby [--yjit] -I lib bench/request.rb --write` for each gem and JIT, which records the run (gem, commit,
Ruby, YJIT, machine, date) in `docs/benchmarks.json`, then `rake docs:render` rewrites the site's numbers from it.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

A change that is not meant to change an answer proves it on the corpus of 20,000 user agents, against a plain
clone of [fnando/browser](https://github.com/fnando/browser) at `dd88933`, as CI does on every pull request:

```bash
ruby -I path/to/upstream/lib script/corpus_snapshot.rb > /tmp/upstream.jsonl
ruby -I lib script/corpus_snapshot.rb > /tmp/browserx.jsonl
ruby script/corpus_diff.rb /tmp/upstream.jsonl /tmp/browserx.jsonl
```

The diff passes when the answers that differ are exactly those of `corpus/expected_differences.jsonl`: a change
meant to change answers rewrites it with `ruby script/corpus_diff.rb --write …` and shows its diff.

The weekly bot sync (`.github/workflows/bot-sync.yml`) runs the same steps by hand:

```bash
ruby script/sync_bots.rb                         # bots.yml and bot_categories.yml
ruby script/bot_coverage.rb path/to/upstream/lib # docs/bot_coverage.json, and its Markdown table
ruby script/render_docs.rb                       # the site's numbers, from docs/*.json and the lists
```

The numbers of `docs/*.html` sit between `<!-- render:… -->` markers and come from `docs/benchmarks.json`,
`docs/bot_coverage.json`, the bot lists and `corpus/expected_differences.jsonl`: CI fails when a page differs from
what `bundle exec rake docs:render` writes.

To add a bot, add its user agent to `test/ua_bots.yml` and its readable name to `bots.yml` above the synced
section, keyed by a lowercased string the user agent contains. A search engine goes in `test/ua_search_engines.yml`,
`test/ua_bots.yml` and `search_engines.yml`.

### Releasing

Pull requests leave `CHANGELOG.md` alone: a release starts by writing its notes under `## [Unreleased]`, from the
pull requests merged since the last tag, without committing them. Then, from an up-to-date `main` whose CI is
green:

```sh
bin/release minor --dry-run   # the notes and the changes, nothing written
bin/release minor             # or patch, major, or an exact version such as 1.2.0
```

`main` takes no direct push, so `bin/release` dates the Unreleased section and bumps the version on a branch
`release/vX.Y.Z`, opens its pull request, which merges itself once CI is green, and waits for it. It then pushes a
signed tag `vX.Y.Z` on the merge commit (`bin/release --tag X.Y.Z` does it if you stopped waiting). The tag starts
the Release workflow, which publishes the gem to RubyGems through trusted publishing and creates the GitHub release
with the version's notes and the `.gem`.

## License

MIT, by Level UP Solutions, see [LICENSE.md](LICENSE.md). Originally written by Nando Vieira as
[fnando/browser](https://github.com/fnando/browser) (MIT). The corpus gathers user agents from
[ua-parser/uap-core](https://github.com/ua-parser/uap-core) (Apache 2.0),
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT) and browser's test fixtures; the bot
list and its categories come from [crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT)
and [ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) (MIT): see
[corpus/SOURCES.md](corpus/SOURCES.md).
