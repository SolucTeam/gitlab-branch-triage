# frozen_string_literal: true

require "rake"

desc "Run tests"
task :test do
  Dir["spec/*_test.rb"].each do |test_file|
    sh "ruby #{test_file}"
  end
end

desc "Build the gem"
task :build do
  sh "gem build gitlab-branch-triage.gemspec"
end

task default: :test
