# smolagents-ruby Rakefile
# Agent-friendly tasks for development workflow
#
# USAGE FOR AGENTS:
#   rake lint        - Check code style (files on disk)
#   rake fix         - Auto-fix code style issues
#   rake spec        - Run test suite
#   rake check       - Full check (lint + spec)
#   rake commit_prep - Prepare for commit (fix, stage, verify)
#
# IMPORTANT: RuboCop checks FILES ON DISK, but pre-commit hooks check STAGED CONTENT.
# Use `rake commit_prep` to ensure staged content will pass the pre-commit hook.

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"
require "yard"
require "yard/doctest/rake"

# =============================================================================
# Core Tasks (Agent-Friendly)
# =============================================================================

desc "Check code style with RuboCop (files on disk)"
task :lint do
  sh "bundle exec rubocop --format simple"
end

desc "Auto-fix RuboCop issues"
task :fix do
  sh "bundle exec rubocop -A --format simple"
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--format progress"
end

desc "Run fast tests only (excludes slow and integration)"
task :spec_fast do
  sh "bundle exec rspec --format progress --tag '~slow' --tag '~integration'"
end

desc "Full check: lint + spec"
task check: %i[lint spec] do
  puts "\nAll checks passed!"
end

# =============================================================================
# Commit Workflow (Critical for Agents)
# =============================================================================

desc "Check STAGED content (simulates pre-commit hook)"
task :staged_lint do
  puts "Checking STAGED content (what pre-commit sees)..."
  staged_files = `git diff --cached --name-only --diff-filter=ACMR`.split("\n")
  ruby_files = staged_files.select { |f| f.end_with?(".rb", ".rake") }

  if ruby_files.empty?
    puts "No staged Ruby files to check"
    next
  end

  # Check each staged file's content (not working directory version)
  errors = []
  ruby_files.each do |file|
    # Get staged content and pipe to rubocop
    result = system("git show ':#{file}' | bundle exec rubocop --stdin '#{file}' --format simple 2>/dev/null")
    errors << file unless result
  end

  if errors.any?
    abort "Staged content has RuboCop errors in: #{errors.join(", ")}"
  else
    puts "All staged Ruby files pass RuboCop"
  end
end

desc "Prepare for commit: fix issues, stage changes, verify staged content"
task :commit_prep do
  puts "=== Step 1: Auto-fixing code style ==="
  system("bundle exec rubocop -A --format simple") # Don't fail on unfixable

  puts "\n=== Step 2: Staging all Ruby changes ==="
  # Stage files individually to avoid errors on missing patterns
  %w[lib spec .rubocop.yml spec/.rubocop.yml Rakefile Makefile CLAUDE.md].each do |path|
    system("git add -A -- #{path} 2>/dev/null")
  end

  puts "\n=== Step 3: Verifying staged content ==="
  Rake::Task[:staged_lint].invoke

  puts "\n=== Ready for commit ==="
  puts "Run: git commit -m 'your message'"
end

# =============================================================================
# RuboCop (Standard)
# =============================================================================

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ["--format", "simple"]
end

RuboCop::RakeTask.new(:rubocop_fix) do |t|
  t.options = ["-A", "--format", "simple"]
end

# =============================================================================
# Documentation
# =============================================================================

YARD::Rake::YardocTask.new(:doc) do |t|
  t.files = ["lib/**/*.rb"]
  t.options = ["--output-dir", "doc"]
end

YARD::Doctest::RakeTask.new do |task|
  task.doctest_opts = ["-v"]
  task.pattern = "lib/**/*.rb"
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

  desc "Serve documentation locally with auto-reload"
  task :server do
    sh "yard server --reload"
  end

  desc "Show documentation coverage statistics"
  task(:stats) { sh "yard stats --list-undoc" }

  desc "Check documentation coverage meets threshold (90%)"
  task(:coverage) { check_yard_coverage }
end

# =============================================================================
# Coverage
# =============================================================================

namespace :coverage do
  desc "Run tests with coverage report"
  task :run do
    ENV["COVERAGE"] = "true"
    Rake::Task[:spec].invoke
    puts "\nCoverage report: coverage/index.html"
  end

  desc "Open coverage report in browser"
  task :open do
    sh "open coverage/index.html" if RUBY_PLATFORM.include?("darwin")
  end

  desc "Check all coverage (code + docs)"
  task all: ["coverage:run", "doc:coverage"]
end

# =============================================================================
# Default
# =============================================================================

task default: %i[lint spec]

# =============================================================================
# Help
# =============================================================================

desc "Show available tasks with descriptions"
task :help do
  puts <<~HELP
    smolagents-ruby development tasks

    AGENT WORKFLOW (use these):
      rake lint          Check code style (files on disk)
      rake fix           Auto-fix RuboCop issues
      rake spec          Run test suite
      rake spec_fast     Run tests excluding slow/integration
      rake check         Full check: lint + spec
      rake commit_prep   FIX → STAGE → VERIFY (use before committing!)
      rake staged_lint   Check staged content (simulates pre-commit)

    IMPORTANT: Pre-commit hooks check STAGED content, not files on disk.
    Always use `rake commit_prep` before committing to avoid failures.

    OTHER TASKS:
      rake doc           Generate YARD documentation
      rake doc:stats     Show documentation coverage
      rake coverage:run  Run tests with coverage report
      rake help          Show this help

    MAKEFILE EQUIVALENT:
      make lint          = rake lint
      make fix           = rake fix
      make test          = rake spec
      make commit-prep   = rake commit_prep
  HELP
end
