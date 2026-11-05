# frozen_string_literal: true

require "test_helper"
require "open3"

class EagerLoadTest < Minitest::Test
  # A fresh process: in this one, earlier tests have already built the caches.
  test "leaves nothing for the first request to load or build" do
    lib_path = File.expand_path("../../lib", __dir__)
    first_request = <<~RUBY
      require "browser"
      Browser.eager_load!
      Browser.define_singleton_method(:load_data) { |name| raise "loaded \#{name} after eager_load!" }
      Browser::Bot.singleton_class.send(:define_method, :trie_source) { |_words| raise "built a trie after eager_load!" }
      browser = Browser.new("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        accept_language: "fr-FR,fr;q=0.9")
      browser.bot.category
      browser.bot.search_engine?
      browser.bot.verified?("66.249.66.1")
      browser.platform.name
      browser.device.name
      browser.accept_language.map(&:name)
      browser.meta
    RUBY
    _output, errors, status = Open3.capture3(RbConfig.ruby, "-I", lib_path, "-e", first_request)

    assert status.success?, errors
  end
end
