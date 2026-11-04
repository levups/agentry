# Corpus sources

`user_agents.txt` gathers, deduplicated, the user agents of:

- [ua-parser/uap-core](https://github.com/ua-parser/uap-core) test cases (`tests/test_ua.yaml`, `test_os.yaml`,
  `test_device.yaml`, `test_resources/firefox_user_agent_strings.yaml`), Apache License 2.0
- [monperrus/crawler-user-agents](https://github.com/monperrus/crawler-user-agents) `instances`, MIT
- the test fixtures of [fnando/browser](https://github.com/fnando/browser) (`test/ua*.yml`), MIT

`script/corpus_build.rb` rebuilds it from `corpus/sources/`, which is not committed.

## Bot list

`script/sync_bots.rb` writes the synced part of `bots.yml` and `bot_categories.yml` from:

- [monperrus/crawler-user-agents](https://github.com/monperrus/crawler-user-agents) `crawler-user-agents.json`
  (patterns and tags), MIT, Copyright (c) 2017 Martin Monperrus
- [ai-robots-txt/ai.robots.txt](https://github.com/ai-robots-txt/ai.robots.txt) `robots.json` (names and
  functions), MIT, Copyright (c) 2024 ai.robots.txt

## Crawler IP ranges

`script/sync_ip_ranges.rb` writes `bot_ip_ranges.yml` from the JSON files each owner publishes so that sites can
verify its crawlers (the URLs are in `Browser::Bot::IPRanges::SOURCES`): Google (common crawlers, special crawlers,
user-triggered fetchers and agents), Bing (bingbot), OpenAI (GPTBot, OAI-SearchBot, ChatGPT-User), Apple
(Applebot), Perplexity (PerplexityBot, Perplexity-User) and DuckDuckGo (DuckDuckBot, DuckAssistBot).

`expected_differences.jsonl` lists the answers on `user_agents.txt` where BrowserX differs from fnando/browser at
`dd88933`, written by `script/corpus_diff.rb --write`.
