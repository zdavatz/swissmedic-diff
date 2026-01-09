# -*- ruby -*-

require "rubygems"
require "bundler/gem_tasks"
require "rake/testtask"
require "rake/clean"

CLEAN.include FileList["*.log"]

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_*.rb"]
end
