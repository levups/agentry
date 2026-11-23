# frozen_string_literal: true

require "test_helper"

class MobileTest < Minitest::Test
  PREFIX_SOURCE = Agentry::Device.const_get(:MOBILE_PREFIX_REGEX).source
  # Its top-level alternatives: parentheses nest two deep in detectmobilebrowsers.com's list.
  PREFIXES = PREFIX_SOURCE.scan(/(?:[^|()]|\((?:[^()]|\([^()]*\))*\))+/)

  test "reads every prefix of the published list as a whole, starting with a literal byte" do
    assert_equal PREFIX_SOURCE, PREFIXES.join("|")
    assert_empty PREFIXES.grep_v(/\A[a-z0-9]/)
  end

  # Every 4 characters the published prefix list accepts, found by trying each 2-character start it names with every
  # pair of the characters it uses, in either case.
  test "finds a mobile in every user agent starting with a published prefix" do
    published = Regexp.new("\\A(?:#{PREFIX_SOURCE})")
    characters = PREFIX_SOURCE.delete("|()[]\\").chars.uniq
    starts = PREFIXES.map { |prefix| prefix[0, 2] }.uniq
      .flat_map { |start| characters.product(characters).map { |third, fourth| start + third + fourth } }
      .select { |start| published.match?(start) }

    assert_operator starts.size, :>, 300
    starts.each do |start|
      assert Agentry::Device.new("#{start} Agent/1.0").mobile?, start
      assert Agentry::Device.new("#{start.swapcase} Agent/1.0").mobile?, start.swapcase
    end
  end

  # A non-ASCII user agent takes the case-insensitive regexps; an ASCII one, the faster lowercase copies. A trailing
  # "é" changes no answer, so both paths must agree.
  test "answers mobile? alike for an ASCII user agent and its non-ASCII twin" do
    random = Random.new(20_261_123)
    characters = [*"a".."z", *"A".."Z", *"0".."9", " ", "-", "_", "/", "."]

    Array.new(10_000) { Array.new(4) { characters.sample(random:) }.join }.each do |start|
      user_agent = "#{start} Agent/1.0"

      assert_equal Agentry::Device.new("#{user_agent} é").mobile?, Agentry::Device.new(user_agent).mobile?, user_agent
    end
  end
end
