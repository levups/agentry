# frozen_string_literal: true

# Writes data/*.json from the *.yml at the root, the files BrowserX reads at runtime: JSON loads them about 30
# times faster than YAML without Bootsnap. The YAML stays the source, with its comments and its curated part;
# DataTest fails on a stale JSON.
#   ruby script/build_data.rb
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)

Dir[File.join(ROOT, "*.yml")].sort.each do |source|
  path = File.join(ROOT, "data", "#{File.basename(source, ".yml")}.json")
  # ASCII only: JSON.load_file reads with the locale's encoding before json 2.8 (Ruby 3.3).
  json = "#{JSON.generate(YAML.load_file(source), ascii_only: true)}\n"
  next if File.exist?(path) && File.read(path) == json

  File.write(path, json)
  puts "Wrote #{path.delete_prefix("#{ROOT}/")}"
end
