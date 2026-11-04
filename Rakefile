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
