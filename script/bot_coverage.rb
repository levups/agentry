# frozen_string_literal: true

# Counts, per category, the bots of tmp/bot_sources/ (written by
# script/sync_bots.rb) that fnando/browser and Agentry call bots, into
# docs/bot_coverage.json, and prints it as a Markdown table.
#   ruby script/bot_coverage.rb path/to/upstream/lib
require "json"
require_relative "sync_bots"

COVERAGE_PATH = File.join(ROOT, "docs/bot_coverage.json")
# ai.robots.txt names its bots without a user agent: each gets the form the AI
# agents of 2026 send. No "bot" or URL in it, or every name would match.
AI_USER_AGENT_FORMAT =
  "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; %s/1.0) Chrome/130.0.0.0 Safari/537.36"
# The site's headline figure: crawlers browser could have known, test drivers
# and scanners left out (crawler-user-agents tags, "addition_date" as 2024/01/01).
RECENT_SINCE = "2024/01/01"
NOT_CRAWLER_TAGS = %w[browser-automation scanner].freeze

def answers(lib, user_agents, question)
  script = "STDIN.each_line { |line| puts JSON.generate(Browser.new(JSON.parse(line)).#{question}) }"
  IO.popen(["ruby", "-I", lib, "-rjson", "-rbrowser", "-e", script], "r+") do |io|
    user_agents.each { io.puts(JSON.generate(_1)) }
    io.close_write
    io.each_line.map { JSON.parse(_1) }
  end
end

category_by_user_agent = {}
crawler_entries.each { |entry| entry[:instances].each { category_by_user_agent[_1] ||= entry[:category] } }
ai_entries.each { category_by_user_agent[format(AI_USER_AGENT_FORMAT, _1[:name])] ||= _1[:category] }

user_agents = category_by_user_agent.keys.sort
upstream_bots = answers(ARGV.fetch(0), user_agents, "bot?")
agentry_bots = answers(File.join(ROOT, "lib"), user_agents, "bot?")
agentry_categories = answers(File.join(ROOT, "lib"), user_agents, "bot.category")

rows = user_agents.each_index.group_by { category_by_user_agent[user_agents[_1]] }.sort.map do |category, indexes|
  {"category" => category, "user_agents" => indexes.size,
   "upstream_bots" => indexes.count { upstream_bots[_1] },
   "agentry_bots" => indexes.count { agentry_bots[_1] },
   "agentry_categorized" => indexes.count { agentry_categories[_1] }}
end
total = rows.first.keys.drop(1).to_h { |column| [column, rows.sum { _1[column] }] }

recent_user_agents = read_source("crawler-user-agents.json")
  .select { (_1["addition_date"] || "") >= RECENT_SINCE && !_1["tags"].intersect?(NOT_CRAWLER_TAGS) }
  .flat_map { _1["instances"] }.uniq
recent_crawlers = {
  "added_since" => RECENT_SINCE.tr("/", "-"), "left_out_tags" => NOT_CRAWLER_TAGS,
  "user_agents" => recent_user_agents.size,
  "upstream_bots" => answers(ARGV.fetch(0), recent_user_agents, "bot?").count(true),
  "agentry_bots" => answers(File.join(ROOT, "lib"), recent_user_agents, "bot?").count(true)
}

File.write(COVERAGE_PATH, JSON.pretty_generate({"upstream" => "fnando/browser dd88933",
  "sources" => SOURCE_URLS.values, "categories" => rows, "total" => total,
  "recent_crawlers" => recent_crawlers}) + "\n")

puts "| Category | User agents | browser | Agentry | With a category |"
puts "|---|--:|--:|--:|--:|"
(rows + [total.merge("category" => "**Total**")]).each do |row|
  puts "| #{row["category"]} | #{row.values_at("user_agents", "upstream_bots", "agentry_bots", "agentry_categorized").join(" | ")} |"
end
puts
puts "Crawler user agents added since #{recent_crawlers["added_since"]}, tags #{NOT_CRAWLER_TAGS.join(" and ")} " \
  "left out: #{recent_crawlers["user_agents"]}, browser misses " \
  "#{recent_crawlers["user_agents"] - recent_crawlers["upstream_bots"]}, Agentry " \
  "#{recent_crawlers["user_agents"] - recent_crawlers["agentry_bots"]}."
