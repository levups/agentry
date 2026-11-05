# frozen_string_literal: true

require "bundler/setup"
require "bundler/gem_tasks"

require "rake/testtask"
Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = false
end

require "rubocop/rake_task"
RuboCop::RakeTask.new do |t|
  t.options += %w[--display-style-guide --display-cop-names --extra-details]
end

task default: %i[test rubocop]

namespace :docs do
  desc "Highlight the code blocks of docs/*.html with Rouge"
  task :highlight do
    ruby "script/highlight_docs.rb"
  end

  desc "Fail if a code block of docs/*.html is not highlighted"
  task "highlight:check" do
    ruby "script/highlight_docs.rb", "--check"
  end

  desc "Render the numbers of docs/*.html from docs/benchmarks.json and docs/bot_coverage.json"
  task :render do
    ruby "script/render_docs.rb"
  end

  desc "Fail if a number of docs/*.html is not rendered from its JSON file"
  task "render:check" do
    ruby "script/render_docs.rb", "--check"
  end
end

desc "Benchmark fnando/browser (UPSTREAM=path/to/upstream) and Agentry into docs/benchmarks.json, then render it"
task :bench do
  upstream_lib = File.join(ENV.fetch("UPSTREAM") { abort "UPSTREAM=path/to/a clone of fnando/browser at dd88933" }, "lib")
  # Outside the bundle, or bundler/setup would put Agentry's lib on upstream's load path.
  Bundler.with_unbundled_env do
    [["--yjit"], []].each do |jit|
      [upstream_lib, "lib"].each { |lib| ruby(*jit, "-I", lib, "bench/request.rb", "--write") }
    end
  end
  Rake::Task["docs:render"].invoke
end
