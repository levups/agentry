# frozen_string_literal: true

require "test_helper"

class DataTest < Minitest::Test
  SOURCES = Dir[Agentry.root.join("*.yml")].sort

  test "each data/*.json holds its YAML source (ruby script/build_data.rb)" do
    refute_empty SOURCES
    SOURCES.each do |source|
      name = File.basename(source, ".yml")

      assert_equal YAML.load_file(source), Agentry.load_data(name), "data/#{name}.json is stale"
    end
    assert_equal SOURCES.size, Dir[Agentry.root.join("data/*.json")].size
  end

  test "the gem ships the JSON, not the YAML it is written from" do
    files = Dir.chdir(Agentry.root) { Gem::Specification.load("agentry.gemspec").files }

    SOURCES.each do |source|
      name = File.basename(source, ".yml")

      assert_includes files, "data/#{name}.json"
      refute_includes files, "#{name}.yml"
    end
  end

  # A shorter one still matches, but every user agent then pays a narrower window in Bot.known_bot_rank.
  test "keeps every bots.yml keyword 4 bytes or longer" do
    assert_empty YAML.load_file(Agentry.root.join("bots.yml")).keys.select { |keyword| keyword.to_s.bytesize < 4 }
  end

  test "load_yaml reads a bundled list from its JSON" do
    bots = YAML.load_file(Agentry.root.join("bots.yml"))

    assert_equal bots, Agentry::Bot.load_yaml("bots.yml")
    assert_equal bots, Agentry::Bot.load_yaml(Pathname("bots.yml"))
    assert_equal YAML.load_file(Agentry.root.join("test/ua_bots.yml")), Agentry::Bot.load_yaml("test/ua_bots.yml")
  end
end
