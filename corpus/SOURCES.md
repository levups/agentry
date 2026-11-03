# Corpus sources

`user_agents.txt` gathers, deduplicated, the user agents of:

- [ua-parser/uap-core](https://github.com/ua-parser/uap-core) test cases (`tests/test_ua.yaml`, `test_os.yaml`,
  `test_device.yaml`, `test_resources/firefox_user_agent_strings.yaml`), Apache License 2.0
- [monperrus/crawler-user-agents](https://github.com/monperrus/crawler-user-agents) `instances`, MIT
- the test fixtures of [fnando/browser](https://github.com/fnando/browser) (`test/ua*.yml`), MIT

`script/corpus_build.rb` rebuilds it from `corpus/sources/`, which is not committed.
