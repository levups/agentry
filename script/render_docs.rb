# frozen_string_literal: true

# Rewrites, in place, every <!-- render:name -->…<!-- /render:name --> block of
# docs/*.html from docs/benchmarks.json (bench/request.rb --write),
# docs/bot_coverage.json (script/bot_coverage.rb), the bot lists and
# corpus/expected_differences.jsonl: no number of the site is typed by hand.
# --check writes nothing and exits 1 if a page would change.
require "cgi"
require "json"
require "yaml"

DOCS_DIRECTORY = File.expand_path("../docs", __dir__)
ROOT = File.expand_path("..", __dir__)
BLOCK = %r{(<!-- render:([\w-]+) -->\n)(.*?)(^[ \t]*<!-- /render:\2 -->)}m
SCENARIO_DISTINCT = "2000 distinct user agents"
SCENARIO_REPEATED = "20 user agents, repeated"

def read_json(name)
  JSON.parse(File.read(File.join(DOCS_DIRECTORY, name)))
end

def benchmark_runs
  @benchmark_runs ||= read_json("benchmarks.json").fetch("runs")
end

def coverage
  @coverage ||= read_json("bot_coverage.json")
end

def number(value)
  value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end

def microseconds(value)
  (value < 10) ? format("%.1f µs", value) : "#{value.round} µs"
end

def run(gem, yjit:)
  benchmark_runs.find { _1["gem"] == gem && _1["yjit"] == yjit } ||
    abort("docs/benchmarks.json has no #{gem} run #{yjit ? "with" : "without"} YJIT: run bench/request.rb --write")
end

def scenario(run, label)
  run.fetch("scenarios").find { _1["scenario"] == label }
end

def gem_label(run)
  "#{run["gem"]} #{run["version"]}"
end

# A table compares runs made on one Ruby and one machine, or it compares machines.
def measurement_note
  rubies = benchmark_runs.map { _1["ruby"][/\Aruby (\S+)/, 1] }.uniq
  machines = benchmark_runs.map { _1["machine"] }.uniq
  abort "docs/benchmarks.json mixes Rubies or machines (#{(rubies + machines).join(", ")}): rerun them all" if
    rubies.size > 1 || machines.size > 1

  dates = benchmark_runs.map { _1["measured_on"] }.uniq.sort
  commits = benchmark_runs.map { "#{gem_label(_1)} at <code>#{_1["commit"]}</code>" }.uniq
  "Ruby #{rubies.first}, #{CGI.escapeHTML(machines.first)}, measured on #{dates.join(" and ")}: " \
    "#{commits.join(", ")}. Each figure is the median of 7 runs."
end

def tile(value, label, detail)
  %(<div class="tile"><span class="tile-value">#{value}</span><span class="tile-label">#{label}</span>) +
    %(<span class="tile-detail">#{detail}</span></div>)
end

def recent_missed(gem)
  recent = coverage.fetch("recent_crawlers")
  recent["user_agents"] - recent[(gem == "browser") ? "upstream_bots" : "agentry_bots"]
end

def recent_crawlers
  recent = coverage.fetch("recent_crawlers")
  "the #{number(recent["user_agents"])} crawler user agents added to crawler-user-agents since " \
    "#{recent["added_since"][0, 4]} (test drivers and scanners left out)"
end

RENDERERS = {
  "lede" => lambda do
    upstream = scenario(run("browser", yjit: true), SCENARIO_DISTINCT)
    agentry = run("Agentry", yjit: true)
    "<p class=\"summary\">#{microseconds(scenario(agentry, SCENARIO_DISTINCT)["microseconds"])} per request " \
      "instead of #{microseconds(upstream["microseconds"])} with browser, " \
      "#{microseconds(scenario(agentry, SCENARIO_REPEATED)["microseconds"])} once a user agent was seen (YJIT). " \
      "Of #{recent_crawlers}, browser misses " \
      "#{number(recent_missed("browser"))} and Agentry #{number(recent_missed("Agentry"))}.</p>"
  end,

  "numbers" => lambda do
    upstream = run("browser", yjit: true)
    agentry = run("Agentry", yjit: true)
    distinct = scenario(agentry, SCENARIO_DISTINCT)
    [
      %(<div class="tiles">),
      tile(microseconds(distinct["microseconds"]), "per request",
        "instead of #{microseconds(scenario(upstream, SCENARIO_DISTINCT)["microseconds"])} with " \
        "#{gem_label(upstream)}, on 2,000 distinct user agents"),
      tile(microseconds(scenario(agentry, SCENARIO_REPEATED)["microseconds"]), "for a repeated user agent",
        "instead of #{microseconds(scenario(upstream, SCENARIO_REPEATED)["microseconds"])}: detection is cached " \
        "per user agent"),
      tile(number(recent_missed("browser")), "recent crawlers browser misses",
        "of #{recent_crawlers}; Agentry misses #{number(recent_missed("Agentry"))}"),
      "</div>",
      %(<p class="note more">#{measurement_note} YJIT on.</p>)
    ].join("\n")
  end,

  "benchmarks" => lambda do
    rows = [true, false].flat_map do |yjit|
      upstream = run("browser", yjit:)
      agentry = run("Agentry", yjit:)
      [SCENARIO_DISTINCT, SCENARIO_REPEATED].map do |label|
        before = scenario(upstream, label)
        after = scenario(agentry, label)
        "<tr><td>#{label}</td><td>#{yjit ? "YJIT" : "none"}</td>" \
          "<td class=\"number\">#{format("%.2f", before["microseconds"])}</td>" \
          "<td class=\"number\">#{format("%.2f", after["microseconds"])}</td>" \
          "<td class=\"number\">#{format("%.1f×", before["microseconds"] / after["microseconds"])}</td>" \
          "<td class=\"number\">#{before["objects"]} → #{after["objects"]}</td></tr>"
      end
    end
    [
      %(<p class="note">#{measurement_note}</p>),
      %(<div class="table-scroll"><table class="options">),
      %(<thead><tr><th scope="col">User agents</th><th scope="col">JIT</th>) +
        %(<th scope="col" class="number">#{gem_label(run("browser", yjit: true))} µs</th>) +
        %(<th scope="col" class="number">#{gem_label(run("Agentry", yjit: true))} µs</th>) +
        %(<th scope="col" class="number">Faster</th><th scope="col" class="number">Objects</th></tr></thead>),
      "<tbody>", *rows, "</tbody>", "</table></div>"
    ].join("\n")
  end,

  "switch-day" => lambda do
    differences = File.foreach(File.join(ROOT, "corpus/expected_differences.jsonl")).map { JSON.parse(_1) }
    new_bots = differences.count { _1["path"] == "browser.bot?" && _1["actual"] == true }
    named_bots = differences.count { _1["path"] == "bot.name" && _1["expected"] == "Generic Bot" }
    [
      "<li><strong>More bots, from the day you switch.</strong> #{number(new_bots)} user agents of the corpus that " \
        "browser took for humans are bots for Agentry: AI crawlers and assistants (<code>meta-externalagent</code>, " \
        "<code>Perplexity-User</code>, <code>Claude-User</code>), ad and SEO crawlers, monitors, feed readers, " \
        "scanners. Analytics that leave bots out count fewer visitors from that day, and anything gated by " \
        "<code>bot?</code> (a session, a captcha, a cache) treats them as bots. Note the date of the switch next " \
        "to your traffic charts. <a href=\"bots.html#coverage\">Coverage per category</a>.</li>",
      "<li><strong>Names for bots.</strong> #{number(named_bots)} user agents that browser named " \
        "<code>Generic Bot</code> get the name of their bot. No name browser gave changes.</li>"
    ].join("\n")
  end,

  "bot-lists" => lambda do
    bots = YAML.load_file(File.join(ROOT, "bots.yml"))
    categories = YAML.load_file(File.join(ROOT, "bot_categories.yml"))
    [
      %(<div class="tiles">),
      tile(number(bots.size), "named bots", "<code>bots.yml</code>, keyed by a lowercase substring of the user agent"),
      tile(categories.size, "categories",
        "<code>bot_categories.yml</code>: <code>ai_crawler</code>, <code>search_engine_crawler</code>, " \
        "<code>scanner</code>…"),
      tile(YAML.load_file(File.join(ROOT, "search_engines.yml")).size, "search engines",
        "<code>search_engines.yml</code>: answer <code>bot.search_engine?</code>"),
      tile(YAML.load_file(File.join(ROOT, "bot_exceptions.yml")).size, "exceptions",
        "<code>bot_exceptions.yml</code>: never a bot, whatever a matcher says"),
      "</div>"
    ].join("\n")
  end,

  "coverage" => lambda do
    rows = coverage.fetch("categories").map do |row|
      "<tr><td><code>#{row["category"]}</code></td><td class=\"number\">#{number(row["user_agents"])}</td>" \
        "<td class=\"number\">#{number(row["upstream_bots"])}</td>" \
        "<td class=\"number\">#{number(row["agentry_bots"])}</td>" \
        "<td class=\"number\">#{number(row["agentry_categorized"])}</td></tr>"
    end
    total = coverage.fetch("total")
    [
      %(<p class="note">Of #{recent_crawlers}, browser misses #{number(recent_missed("browser"))} and ) +
        %(Agentry #{number(recent_missed("Agentry"))}. Against #{coverage["upstream"]}.</p>),
      %(<div class="table-scroll"><table class="options">),
      %(<thead><tr><th scope="col">Category</th><th scope="col" class="number">User agents</th>) +
        %(<th scope="col" class="number">browser: <code>bot?</code></th>) +
        %(<th scope="col" class="number">Agentry: <code>bot?</code></th>) +
        %(<th scope="col" class="number">Agentry: a category</th></tr></thead>),
      "<tbody>", *rows, "</tbody>",
      "<tfoot><tr><th scope=\"row\">Total</th><td class=\"number\">#{number(total["user_agents"])}</td>" \
        "<td class=\"number\">#{number(total["upstream_bots"])}</td>" \
        "<td class=\"number\">#{number(total["agentry_bots"])}</td>" \
        "<td class=\"number\">#{number(total["agentry_categorized"])}</td></tr></tfoot>",
      "</table></div>"
    ].join("\n")
  end
}.freeze

def render(page, path)
  page.gsub(BLOCK) do
    opening, name, _stale, closing = Regexp.last_match.captures
    renderer = RENDERERS[name] || abort("#{path}: no renderer for render:#{name}")
    indentation = closing[/\A[ \t]*/]
    "#{opening}#{renderer.call.lines.map { "#{indentation}#{_1}" }.join}\n#{closing}"
  end
end

check = ARGV.include?("--check")
stale_paths = Dir[File.join(DOCS_DIRECTORY, "*.html")].sort.select do |path|
  page = File.read(path)
  rendered = render(page, path)
  next false if rendered == page

  File.write(path, rendered) unless check
  true
end

relative_paths = stale_paths.map { |path| File.join("docs", File.basename(path)) }
abort "Not rendered: #{relative_paths.join(", ")}. Run bundle exec rake docs:render" if check && stale_paths.any?
puts "Rendered #{relative_paths.join(", ")}" if stale_paths.any?
