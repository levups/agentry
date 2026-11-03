# frozen_string_literal: true

# Prints, for each user agent of corpus/user_agents.txt, everything the public
# API answers with no argument, one JSON line per user agent. Run it against
# any copy of the gem to compare two builds:
#   ruby -I path/to/lib script/corpus_snapshot.rb > snapshot.jsonl
require "json"
require "browser"

UNSNAPSHOTTED_METHODS = %i[to_a meta inspect].freeze
LITERAL_VALUES = [true, false].freeze

def callable_methods(klass, owner_classes)
  methods =
    owner_classes.flat_map { |owner| owner.public_instance_methods(false) }
  methods = methods.uniq.select do |name|
    arity = klass.instance_method(name).arity
    arity.zero? || arity == -1
  rescue NameError
    false
  end
  methods.sort - UNSNAPSHOTTED_METHODS
end

def snapshot_value(value)
  value = value.to_s if value.is_a?(Symbol)
  return value if value.nil? || LITERAL_VALUES.include?(value)
  return value if value.is_a?(String) || value.is_a?(Numeric)

  "<object>"
end

def answers(object, methods)
  methods.to_h do |name|
    value = begin
      object.public_send(name)
    rescue => error
      "!#{error.class}"
    end
    [name, snapshot_value(value)]
  end
end

browser_classes = [Browser::Base, *Browser.matchers]
platform_classes = [Browser::Platform]
device_classes = [Browser::Device]
user_agents_path = File.expand_path("../corpus/user_agents.txt", __dir__)

File.foreach(user_agents_path, chomp: true) do |user_agent|
  browser = Browser.new(user_agent)
  owner_classes = browser_classes.select { |klass| browser.is_a?(klass) }
  row = {
    ua: user_agent,
    class: browser.class.name,
    browser: answers(browser, callable_methods(browser.class, owner_classes)),
    meta: browser.meta.sort,
    platform: answers(browser.platform,
      callable_methods(Browser::Platform, platform_classes)),
    device: answers(browser.device,
      callable_methods(Browser::Device, device_classes)),
    bot: answers(browser.bot, %i[bot? name search_engine?])
  }
  puts JSON.generate(row)
end
