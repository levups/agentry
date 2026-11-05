# frozen_string_literal: true

require "test_helper"

class DataTest < Minitest::Test
  SOURCES = Dir[Browser.root.join("*.yml")].sort

  test "each data/*.json holds its YAML source (ruby script/build_data.rb)" do
    refute_empty SOURCES
    SOURCES.each do |source|
      name = File.basename(source, ".yml")

      assert_equal YAML.load_file(source), Browser.load_data(name), "data/#{name}.json is stale"
    end
    assert_equal SOURCES.size, Dir[Browser.root.join("data/*.json")].size
  end

  test "the gem ships the JSON, not the YAML it is written from" do
    files = Dir.chdir(Browser.root) { Gem::Specification.load("browserx.gemspec").files }

    SOURCES.each do |source|
      name = File.basename(source, ".yml")

      assert_includes files, "data/#{name}.json"
      refute_includes files, "#{name}.yml"
    end
  end

  test "load_yaml reads a bundled list from its JSON" do
    bots = YAML.load_file(Browser.root.join("bots.yml"))

    assert_equal bots, Browser::Bot.load_yaml("bots.yml")
    assert_equal bots, Browser::Bot.load_yaml(Pathname("bots.yml"))
    assert_equal YAML.load_file(Browser.root.join("test/ua_bots.yml")), Browser::Bot.load_yaml("test/ua_bots.yml")
  end
end
