# frozen_string_literal: true

# Gathers every distinct user agent from corpus/sources and the upstream test
# fixtures into corpus/user_agents.txt, the input of the equivalence snapshots.
require "json"
require "yaml"

root = File.expand_path("..", __dir__)
sources = File.join(root, "corpus/sources")
user_agents = []

Dir[File.join(sources, "uap-*.yaml")].each do |path|
  YAML.load_file(path)["test_cases"].each do |test_case|
    user_agents << test_case["user_agent_string"]
  end
end
crawlers_path = File.join(sources, "crawler-user-agents.json")
JSON.parse(File.read(crawlers_path)).each do |entry|
  user_agents.concat(entry["instances"] || [])
end
%w[ua.yml ua_bots.yml ua_search_engines.yml].each do |fixture|
  user_agents.concat(YAML.load_file(File.join(root, "test", fixture)).values)
end

user_agents = user_agents.compact
  .map(&:to_s)
  .reject { |user_agent| user_agent.include?("\n") }
  .uniq
File.write(File.join(root, "corpus/user_agents.txt"),
  user_agents.join("\n") << "\n")
puts "#{user_agents.size} user agents"
