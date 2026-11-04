# frozen_string_literal: true

# Rewrites bot_ip_ranges.yml from the IP ranges Google, Bing, OpenAI, Apple, Perplexity and DuckDuckGo publish
# for their crawlers (Browser::Bot::IPRanges::SOURCES).
#   ruby -I lib script/sync_ip_ranges.rb
# The output is sorted, so a run without new ranges changes nothing.
require "browser"
require "yaml"

PATH = File.expand_path("../bot_ip_ranges.yml", __dir__)
HEADER = "# Synced by script/sync_ip_ranges.rb from the IP ranges each owner publishes: do not edit.\n"

prefixes_by_owner = Browser::Bot::IPRanges.fetch.transform_keys(&:to_s)
File.write(PATH, HEADER + YAML.dump(prefixes_by_owner).delete_prefix("---\n"))
prefixes_by_owner.each { |owner, prefixes| warn "#{owner}: #{prefixes.size} prefixes" }
