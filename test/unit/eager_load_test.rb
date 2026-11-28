# frozen_string_literal: true

require "test_helper"
require "open3"

class EagerLoadTest < Minitest::Test
  # A fresh process: in this one, earlier tests have already built the caches. An app may set the cache size after
  # eager_load!, in a preforking server's boot hook.
  {
    "" => ["", ""],
    "and a cache size" => ["Agentry.cache_size = 5_000", ""],
    "and entries renamed in place" => [<<~RUBY, <<~RUBY]
      bots = Agentry::Bot.bots
      bots["renamedfoo"] = bots.delete(bots.keys.first)
      search_engines = Agentry::Bot.search_engines
      search_engines["renamedengine"] = search_engines.delete(search_engines.keys.first)
      Agentry.cache_size = 5_000
    RUBY
      raise "missed the renamed bot" unless Agentry.new("Mozilla/5.0 renamedfoo/1.0").bot?
      raise "missed the renamed engine" unless Agentry::Bot.new("renamedengine/1.0").search_engine?
    RUBY
  }.each do |name, (after_eager_load, after_request)|
    test "leaves nothing for the first request to load or build #{name}".strip do
      lib_path = File.expand_path("../../lib", __dir__)
      first_request = <<~RUBY
        require "agentry"
        Agentry.eager_load!
        #{after_eager_load}
        Agentry.define_singleton_method(:load_data) { |name| raise "loaded \#{name} after eager_load!" }
        Agentry::Bot.singleton_class.send(:define_method, :trie_source) { |_words| raise "built a trie after eager_load!" }
        Agentry::Bot.singleton_class.send(:define_method, :build_known_bots_trie) { raise "built the bots trie after eager_load!" }
        browser = Agentry.new("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
          accept_language: "fr-FR,fr;q=0.9")
        browser.bot.category
        browser.bot.search_engine?
        browser.bot.verified?("66.249.66.1")
        browser.platform.name
        browser.device.name
        browser.accept_language.map(&:name)
        browser.meta
        #{after_request}
      RUBY
      _output, errors, status = Open3.capture3(RbConfig.ruby, "-I", lib_path, "-e", first_request)

      assert status.success?, errors
    end
  end
end
