# frozen_string_literal: true

# Rewrites the synced part of bots.yml and the whole of bot_categories.yml from
# monperrus/crawler-user-agents and ai-robots-txt/ai.robots.txt (both MIT).
#   ruby script/sync_bots.rb            # downloads both lists into tmp/bot_sources/
#   ruby script/sync_bots.rb --offline  # reuses tmp/bot_sources/
# The output is sorted, so a run without new bots changes nothing.
require "fileutils"
require "json"
require "net/http"
require "yaml"

ROOT = File.expand_path("..", __dir__)
SOURCES_DIRECTORY = File.join(ROOT, "tmp/bot_sources")
SOURCE_URLS = {
  "crawler-user-agents.json" =>
    "https://raw.githubusercontent.com/monperrus/crawler-user-agents/master/crawler-user-agents.json",
  "robots.json" =>
    "https://raw.githubusercontent.com/ai-robots-txt/ai.robots.txt/main/robots.json"
}.freeze
BOTS_PATH = File.join(ROOT, "bots.yml")
CATEGORIES_PATH = File.join(ROOT, "bot_categories.yml")
CORPUS_PATH = File.join(ROOT, "corpus/user_agents.txt")
SYNCED_SECTION_MARKER =
  "# Synced from crawler-user-agents and ai.robots.txt by script/sync_bots.rb: edit above this line."

# Categories whose keywords never make bot? true: an app's system tests drive
# a real browser through them.
NOT_BOT_CATEGORIES = %w[browser_automation].freeze

# crawler-user-agents tags, most specific first: an entry tagged
# ["scanner", "seo"] is a scanner.
CATEGORY_BY_TAG = {
  "browser-automation" => "browser_automation",
  "http-library" => "http_library",
  "scanner" => "scanner",
  "ai-crawler" => "ai_crawler",
  "search-engine" => "search_engine_crawler",
  "social-preview" => "page_preview",
  "feed-reader" => "feed_fetcher",
  "advertising" => "advertising_and_marketing",
  "archiver" => "archiver",
  "academic" => "academic_research",
  "monitoring" => "monitoring_and_analytics",
  "seo" => "search_engine_optimization"
}.freeze

# ai.robots.txt's "function" is free text; its usual values first.
AI_CATEGORY_BY_FUNCTION = {
  "AI Agents" => "ai_agent",
  "AI Coding Agents" => "ai_agent",
  "Undocumented AI Agents" => "ai_agent",
  "AI Assistants" => "ai_assistant",
  "AI Search Crawlers" => "ai_search"
}.freeze

# Names a list uses that a human browser's user agent may contain as well.
IGNORED_KEYWORDS = [
  "ap3a.240617.008", "008/", # an Android build number, sent by real phones
  "code/1.", "code", # Visual Studio Code's Electron user agent
  "codex", "cursor", "devin", "dot", "instinct", "muse", "openai", "operator", "spider", "trae", "useai", # plain words
  "gwene", # inside "SomethingWeNeverKnewExisted"
  "speedy", # Yahoo Mail's Android app
  "nextcloud", # Nextcloud's desktop client
  "viber" # Viber's in-app browser
].freeze
# Shorter keywords (bw/, red/, ahc/) turn up inside browser and app user agents.
MIN_KEYWORD_ALPHANUMERICS = 5

# Curated keywords of bots.yml no source categorizes, and keywords a source misreads.
CATEGORY_BY_KEYWORD = {
  "lightpanda" => "browser_automation", # a headless browser, like HeadlessChrome
  "siege" => "http_library",
  "apachebench" => "http_library",
  "coldfusion" => "http_library",
  "dap/nethttp" => "http_library",
  "eventmachine httpclient" => "http_library",
  "go 1.1 package http" => "http_library",
  "go http package" => "http_library",
  "htmlparser" => "http_library",
  "http_request2" => "http_library",
  "jaunt" => "http_library",
  "pycurl" => "http_library",
  "python-httplib2" => "http_library",
  "typhoeus" => "http_library",
  "appsignal" => "monitoring_and_analytics",
  "elb-healthchecker" => "monitoring_and_analytics",
  "google page speed insights" => "monitoring_and_analytics",
  "loadtimebot" => "monitoring_and_analytics",
  "newrelicmonitor" => "monitoring_and_analytics",
  "newrelicpinger" => "monitoring_and_analytics",
  "scouturlmonitor" => "monitoring_and_analytics",
  "wasalive-bot" => "monitoring_and_analytics",
  "comodo ssl checker" => "security",
  "comodo-webinspector-crawler" => "security",
  "awe.sm" => "page_preview",
  "bufferbot" => "page_preview",
  "longurl" => "page_preview",
  "quicklook" => "page_preview",
  "shortlinktranslate" => "page_preview",
  "slack-linkexpanding" => "page_preview"
}.freeze

def fetch_sources
  FileUtils.mkdir_p(SOURCES_DIRECTORY)
  SOURCE_URLS.each do |file_name, url|
    response = Net::HTTP.get_response(URI(url))
    raise "#{url}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    File.write(File.join(SOURCES_DIRECTORY, file_name), response.body)
  end
end

def read_source(file_name)
  JSON.parse(File.read(File.join(SOURCES_DIRECTORY, file_name)))
end

# The literal strings a crawler-user-agents pattern stands for: anchors
# dropped, `[xX]` and `(a|b)` expanded. A pattern needing more than a substring
# keeps its longest literal run, checked against its instances.
def pattern_keywords(pattern)
  source = pattern
    .gsub(/\(\^\| \)|\(\[\^-\]\|\$\)|\^|\$/, "")
    .gsub(/\[([a-zA-Z])([a-zA-Z])\]/) { ($1.casecmp?($2) && $1 != $2) ? $1 : $& }
  alternatives = source.include?("(") ? [source] : source.split("|")
  alternatives.flat_map { |alternative| expand_groups(alternative) }.map do |keyword|
    runs = keyword.split(/\\[dDsSwW]|\[[^\]]*\][*+?]?|\.[*+?]|(?<!\\)[*+?]|(?<!\\)\./)
    runs.map { |run| run.gsub(/\\(.)/, '\1') }.max_by(&:length).strip
  end.uniq(&:downcase)
end

def expand_groups(alternative)
  group = alternative.match(/\(([^()]*)\)/)
  return [alternative] unless group

  group[1].split("|").flat_map do |choice|
    expand_groups(group.pre_match + choice + group.post_match)
  end
end

def crawler_entries
  read_source("crawler-user-agents.json").flat_map do |entry|
    tag = CATEGORY_BY_TAG.keys.find { |known_tag| entry["tags"].include?(known_tag) }
    names = pattern_keywords(entry["pattern"])
    keywords = names.map(&:downcase)
    instances = entry["instances"]
    unless instances.all? { |instance| keywords.any? { instance.downcase.include?(_1) } }
      warn "skipped #{entry["pattern"].inspect}: #{keywords.inspect} misses an instance"
      next []
    end
    names.map do |name|
      {keyword: name.downcase, name: name.delete_suffix("/"), category: CATEGORY_BY_TAG[tag], instances:}
    end
  end
end

def ai_entries
  read_source("robots.json").map do |name, entry|
    category = AI_CATEGORY_BY_FUNCTION.fetch(entry["function"]) do
      case "#{entry["function"]} #{entry["description"]}"
      when /user[- ]initiated|user queries|user prompts|on behalf/i then "ai_assistant"
      when /search/i then "ai_search"
      else "ai_crawler"
      end
    end
    {keyword: name.downcase, name:, category:, instances: []}
  end
end

# A keyword wins its category from the most specific source: ai.robots.txt
# refines crawler-user-agents' "ai-crawler", never a search engine or a scanner.
def merged_entries
  entry_by_keyword = {}
  crawler_entries.each { |entry| entry_by_keyword[entry[:keyword]] ||= entry }
  ai_entries.each do |entry|
    known = entry_by_keyword[entry[:keyword]]
    if known.nil?
      entry_by_keyword[entry[:keyword]] = entry
    else
      known[:name] = entry[:name]
      known[:category] = entry[:category] if known[:category] == "ai_crawler"
    end
  end
  CATEGORY_BY_KEYWORD.each do |keyword, category|
    entry_by_keyword[keyword][:category] = category if entry_by_keyword.key?(keyword)
  end
  entry_by_keyword.except(*IGNORED_KEYWORDS)
end

def curated_section
  File.read(BOTS_PATH).split("#{SYNCED_SECTION_MARKER}\n").first.rstrip
end

# A keyword that would turn into a bot a browser of the corpus (a user agent
# BrowserX knows, which no crawler-user-agents pattern matches) is left out.
def browser_user_agents(curated_bots)
  $LOAD_PATH.unshift(File.join(ROOT, "lib"))
  require "browser"
  # Judged by the curated list alone, or a keyword synced last week would hide the browsers it flags.
  Browser::Bot.instance_variable_set(:@bots, curated_bots)
  crawler_pattern = Regexp.union(read_source("crawler-user-agents.json").map { Regexp.new(_1["pattern"]) })
  File.foreach(CORPUS_PATH, chomp: true).filter_map do |user_agent|
    next if user_agent.length > Browser.user_agent_size_limit
    next if user_agent.match?(crawler_pattern)

    browser = Browser.new(user_agent)
    user_agent.downcase if browser.known? && !browser.bot?
  end
end

def synced_bots(entry_by_keyword, curated_bots)
  browsers = browser_user_agents(curated_bots)
  synced = entry_by_keyword.values.filter_map do |entry|
    next if NOT_BOT_CATEGORIES.include?(entry[:category])
    next if curated_bots.key?(entry[:keyword])
    next if entry[:keyword].count("a-z0-9") < MIN_KEYWORD_ALPHANUMERICS

    browser = browsers.find { _1.include?(entry[:keyword]) }
    if browser
      warn "skipped #{entry[:keyword].inspect}: matches #{browser[0, 100]}"
      next
    end
    [entry[:keyword], entry[:name]]
  end.sort.to_h
  synced.reject { |keyword, _name| contains_another_keyword?(keyword, curated_bots.keys + synced.keys) }
end

# Matching a keyword already matches every keyword containing it.
def contains_another_keyword?(keyword, keywords)
  keywords.any? { |other| other != keyword && keyword.include?(other) }
end

# A curated keyword takes the category of the source entries whose user agents contain it.
def curated_category(keyword, entry_by_keyword)
  return CATEGORY_BY_KEYWORD[keyword] if CATEGORY_BY_KEYWORD.key?(keyword)
  return entry_by_keyword[keyword][:category] if entry_by_keyword.key?(keyword)

  categories = entry_by_keyword.values.filter_map do |entry|
    entry[:category] if entry[:instances].any? { _1.downcase.include?(keyword) }
  end
  categories.tally.max_by { |category, count| [count, category] }&.first
end

def write_bots(synced)
  lines = synced.map { |keyword, name| {keyword => name}.to_yaml.delete_prefix("---\n") }
  File.write(BOTS_PATH, "#{curated_section}\n\n#{SYNCED_SECTION_MARKER}\n#{lines.join}")
end

def write_categories(entry_by_keyword, curated_bots, synced)
  keywords_by_category = Hash.new { |hash, category| hash[category] = [] }
  curated_bots.each_key do |keyword|
    category = curated_category(keyword, entry_by_keyword)
    keywords_by_category[category] << keyword if category
  end
  synced.each_key { |keyword| keywords_by_category[entry_by_keyword[keyword][:category]] << keyword }
  entry_by_keyword.each_value do |entry|
    keywords_by_category[entry[:category]] << entry[:keyword] if NOT_BOT_CATEGORIES.include?(entry[:category])
  end
  sorted = keywords_by_category.sort.to_h { |category, keywords| [category, keywords.uniq.sort] }
  File.write(CATEGORIES_PATH, sorted.to_yaml)
end

# script/bot_coverage.rb reads the same sources.
return unless $PROGRAM_NAME == __FILE__

fetch_sources unless ARGV.include?("--offline")
entry_by_keyword = merged_entries
curated_bots = YAML.safe_load(curated_section) || {}
synced = synced_bots(entry_by_keyword, curated_bots)
write_bots(synced)
write_categories(entry_by_keyword, curated_bots, synced)
puts "#{curated_bots.size} curated bots, #{synced.size} synced, #{entry_by_keyword.size} keywords categorized"
