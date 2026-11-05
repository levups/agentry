# frozen_string_literal: true

# What a web request asks: the browser, whether it is a bot, its platform and
# device.
#   ruby [--yjit] -I path/to/lib bench/request.rb [--write]
# --write also records the run in docs/benchmarks.json, replacing the previous
# run of the same gem and JIT: script/render_docs.rb turns it into the site.
require "json"
require "open3"
require "browser"

ACCEPT_LANGUAGE = "fr-FR,fr;q=0.9,en;q=0.8"
RESULTS_PATH = File.expand_path("../docs/benchmarks.json", __dir__)

user_agents =
  File.foreach(File.expand_path("../corpus/user_agents.txt", __dir__),
    chomp: true)
    .reject { |user_agent| user_agent.length > Browser.user_agent_size_limit }
    .map(&:freeze)
sample = user_agents.each_slice(user_agents.size / 2000).map(&:first)

def request(user_agent)
  browser = Browser.new(user_agent, accept_language: ACCEPT_LANGUAGE)
  [
    browser.name, browser.full_version, browser.bot?, browser.bot.name,
    browser.platform.name, browser.platform.version, browser.device.mobile?,
    browser.device.tablet?, browser.accept_language.first&.code
  ]
end

def measure(label, user_agents, rounds)
  requests = rounds * user_agents.size
  user_agents.each { |user_agent| request(user_agent) }
  timings = Array.new(7) do
    GC.start
    allocated = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    rounds.times { user_agents.each { |user_agent| request(user_agent) } }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    objects = GC.stat(:total_allocated_objects) - allocated
    [elapsed / requests * 1e6, objects / requests]
  end
  microseconds = timings.map(&:first).sort[3]
  printf("%-34s %8.2f µs  %5d objects\n",
    label, microseconds, timings.first.last)
  {"scenario" => label, "microseconds" => microseconds.round(2), "objects" => timings.first.last}
end

def machine
  if RUBY_PLATFORM.include?("darwin")
    model, status = Open3.capture2("sysctl", "-n", "machdep.cpu.brand_string")
    return model.strip if status.success?
  end
  cpu = File.foreach("/proc/cpuinfo").find { _1.start_with?("model name") } if File.exist?("/proc/cpuinfo")
  cpu&.split(":", 2)&.last&.strip || RUBY_PLATFORM
end

# Measured from a checkout: lib/agentry.rb exists in Agentry only.
def measured_gem
  lib = File.dirname($LOAD_PATH.resolve_feature_path("browser").last)
  commit, status = Open3.capture2("git", "-C", lib, "rev-parse", "--short", "HEAD")
  {"gem" => File.exist?(File.join(lib, "agentry.rb")) ? "Agentry" : "browser",
   "version" => Browser::VERSION, "commit" => (commit.strip if status.success?)}
end

scenarios = [
  measure("2000 distinct user agents", sample, 2),
  measure("20 user agents, repeated", sample.first(20), 200)
]

if ARGV.include?("--write")
  run = measured_gem.merge("yjit" => defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? || false,
    "ruby" => RUBY_DESCRIPTION, "machine" => machine, "measured_on" => Time.now.utc.strftime("%F"),
    "scenarios" => scenarios)
  runs = File.exist?(RESULTS_PATH) ? JSON.parse(File.read(RESULTS_PATH)).fetch("runs") : []
  runs = runs.reject { _1.values_at("gem", "yjit") == run.values_at("gem", "yjit") } + [run]
  runs.sort_by! { [_1["yjit"] ? 0 : 1, (_1["gem"] == "browser") ? 0 : 1] }
  File.write(RESULTS_PATH, JSON.pretty_generate({"runs" => runs}) + "\n")
end
