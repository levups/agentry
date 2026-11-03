# frozen_string_literal: true

# What a web request asks: the browser, whether it is a bot, its platform and
# device.
#   ruby [--yjit] -I path/to/lib bench/request.rb
require "browser"

ACCEPT_LANGUAGE = "fr-FR,fr;q=0.9,en;q=0.8"

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
end

measure("2000 distinct user agents", sample, 2)
measure("20 user agents, repeated", sample.first(20), 200)
