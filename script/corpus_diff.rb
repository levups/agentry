# frozen_string_literal: true

# Compares two snapshots from script/corpus_snapshot.rb. Passes when every
# answer that differs is listed in corpus/expected_differences.jsonl, and
# every listed one differs: a fresher bot list changes answers on purpose.
# A method the first snapshot lacks is an addition, not a changed answer.
#   ruby script/corpus_diff.rb upstream.jsonl agentry.jsonl
#   ruby script/corpus_diff.rb --write upstream.jsonl agentry.jsonl # lists them
require "json"

EXPECTED_DIFFERENCES_PATH = File.expand_path("../corpus/expected_differences.jsonl", __dir__)

def flatten(row, prefix = nil)
  row.each_with_object({}) do |(key, value), flat|
    path = [prefix, key].compact.join(".")
    value.is_a?(Hash) ? flat.merge!(flatten(value, path)) : flat[path] = value
  end
end

def read_snapshot(path)
  File.foreach(path).map { |line| JSON.parse(line) }
end

def print_differences(title, differences)
  return if differences.empty?

  puts title
  differences.group_by { _1["path"] }.sort_by { |_path, cases| -cases.size }.each do |path, cases|
    puts "#{path}: #{cases.size} differences"
    cases.first(3).each do |difference|
      puts "  #{difference["expected"].inspect} → #{difference["actual"].inspect}  #{difference["ua"][0, 120]}"
    end
  end
end

write = ARGV.delete("--write")
expected_rows = read_snapshot(ARGV.fetch(0))
actual_rows = read_snapshot(ARGV.fetch(1))
differences = []
expected_rows.zip(actual_rows).each do |expected, actual|
  expected_answers = flatten(expected)
  actual_answers = flatten(actual)
  expected_answers.each_key do |path|
    next if expected_answers[path] == actual_answers[path]

    differences << {"path" => path, "ua" => expected["ua"],
                    "expected" => expected_answers[path], "actual" => actual_answers[path]}
  end
end
differences.sort_by! { [_1["path"], _1["ua"]] }

if write
  File.write(EXPECTED_DIFFERENCES_PATH, differences.map { "#{JSON.generate(_1)}\n" }.join)
  puts "#{differences.size} expected differences written to corpus/expected_differences.jsonl"
  exit
end

listed = File.exist?(EXPECTED_DIFFERENCES_PATH) ? read_snapshot(EXPECTED_DIFFERENCES_PATH) : []
unexpected = differences - listed
missing = listed - differences
if unexpected.empty? && missing.empty?
  puts "#{expected_rows.size} user agents, #{differences.size} differences, all expected"
else
  print_differences("Unexpected differences:", unexpected)
  print_differences("Expected differences that no longer happen:", missing)
  exit 1
end
