require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--output-dir", "doc"]
end

def check_yard_coverage(threshold: 90.0)
  output = `yard stats 2>&1`
  puts output

  match = output.match(/(\d+(?:\.\d+)?)%\s+documented/)
  abort "Could not parse YARD coverage from output" unless match

  coverage = match[1].to_f
  abort "Documentation coverage #{coverage}% is below threshold #{threshold}%" if coverage < threshold

  puts "\nDocumentation coverage: #{coverage}% (threshold: #{threshold}%)"
end

namespace :doc do
  desc "Generate documentation and open in browser"
  task open: :doc do
    sh "open doc/index.html" if RUBY_PLATFORM.include?("darwin")
  end

  desc "Generate documentation and serve locally"
  task :server do
    sh "yard server --reload"
  end

  desc "Show documentation coverage statistics"
  task(:stats) { sh "yard stats --list-undoc" }

  desc "Check documentation coverage meets threshold (90%)"
  task(:coverage) { check_yard_coverage }
end

namespace :coverage do
  desc "Run tests with coverage report"
  task :run do
    ENV["COVERAGE"] = "true"
    Rake::Task[:spec].invoke
    puts "\nCoverage report generated in coverage/index.html"
  end

  desc "Open coverage report in browser"
  task :open do
    sh "open coverage/index.html" if RUBY_PLATFORM.include?("darwin")
  end

  desc "Check all coverage (code + docs)"
  task all: ["coverage:run", "doc:coverage"]
end

task default: %i[spec rubocop]
