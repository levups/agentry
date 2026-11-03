# frozen_string_literal: true

# Compares two snapshots from script/corpus_snapshot.rb and lists every answer
# that differs.
#   ruby script/corpus_diff.rb upstream.jsonl browserx.jsonl
require "json"

def flatten(row, prefix = nil)
  row.each_with_object({}) do |(key, value), flat|
    path = [prefix, key].compact.join(".")
    value.is_a?(Hash) ? flat.merge!(flatten(value, path)) : flat[path] = value
  end
end

def read_snapshot(path)
  File.foreach(path).map {|line| JSON.parse(line) }
end

expected_rows = read_snapshot(ARGV.fetch(0))
actual_rows = read_snapshot(ARGV.fetch(1))
differences = Hash.new {|hash, key| hash[key] = [] }
expected_rows.zip(actual_rows).each do |expected, actual|
  expected_answers = flatten(expected)
  actual_answers = flatten(actual)
  (expected_answers.keys | actual_answers.keys).each do |path|
    next if expected_answers[path] == actual_answers[path]

    differences[path] <<
      [expected["ua"], expected_answers[path], actual_answers[path]]
  end
end

if differences.empty?
  puts "#{expected_rows.size} user agents, identical answers"
else
  differences.sort_by {|_path, cases| -cases.size }.each do |path, cases|
    puts "#{path}: #{cases.size} differences"
    cases.first(3).each do |user_agent, expected, actual|
      puts "  #{expected.inspect} → #{actual.inspect}  #{user_agent[0, 120]}"
    end
  end
  exit 1
end
