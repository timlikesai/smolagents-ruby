# smolagents-ruby Makefile
# Agent-friendly commands for development workflow
#
# USAGE FOR AGENTS:
#   make lint      - Check code style (run before committing)
#   make fix       - Auto-fix code style issues
#   make test      - Run test suite
#   make check     - Full pre-commit check (lint + test)
#   make commit-prep - Prepare for commit (fix, stage, verify)
#
# The key difference from running rubocop directly:
#   `make lint` and `make fix` operate on FILES ON DISK
#   Pre-commit hooks check STAGED CONTENT
#   Use `make commit-prep` to ensure staged content passes

.PHONY: lint fix test check commit-prep staged-lint help install clean

# Default target - show help
help:
	@echo "smolagents-ruby development commands"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint          Check code style with RuboCop (files on disk)"
	@echo "  make fix           Auto-fix RuboCop issues"
	@echo "  make staged-lint   Check STAGED content (what pre-commit sees)"
	@echo ""
	@echo "Testing:"
	@echo "  make test          Run RSpec test suite"
	@echo "  make test-fast     Run tests excluding slow/integration"
	@echo ""
	@echo "Workflow:"
	@echo "  make check         Full check: lint + test"
	@echo "  make commit-prep   Fix issues, stage changes, verify staged content"
	@echo ""
	@echo "Setup:"
	@echo "  make install       Install dependencies"
	@echo "  make clean         Remove generated files"

# Check code style (operates on working directory files)
lint:
	@echo "Checking code style (files on disk)..."
	bundle exec rubocop --format simple

# Auto-fix code style issues
fix:
	@echo "Auto-fixing code style issues..."
	bundle exec rubocop -A --format simple

# Check staged content (what pre-commit hook sees)
# This creates temp files from staged content and runs rubocop on them
staged-lint:
	@echo "Checking STAGED content (simulates pre-commit)..."
	@git diff --cached --name-only --diff-filter=ACMR | grep -E '\.(rb|rake)$$' | \
		xargs -I {} sh -c 'git show :"{}" | bundle exec rubocop --stdin "{}" --format simple' 2>/dev/null || \
		echo "No staged Ruby files to check"

# Run test suite
test:
	@echo "Running test suite..."
	bundle exec rspec --format progress

# Run tests excluding slow and integration tests
test-fast:
	@echo "Running fast tests only..."
	bundle exec rspec --format progress --tag '~slow' --tag '~integration'

# Full pre-commit check
check: lint test
	@echo "All checks passed!"

# Prepare for commit: fix, add, and verify staged content
# Use this workflow:
#   1. make commit-prep
#   2. git commit -m "message"
commit-prep:
	@echo "=== Step 1: Auto-fixing code style ==="
	bundle exec rubocop -A --format simple || true
	@echo ""
	@echo "=== Step 2: Staging all Ruby changes ==="
	git add -A '*.rb' '*.rake' '.rubocop.yml' 'spec/.rubocop.yml' 'Rakefile'
	@echo ""
	@echo "=== Step 3: Verifying staged content ==="
	@$(MAKE) staged-lint
	@echo ""
	@echo "=== Ready for commit ==="
	@echo "Run: git commit -m 'your message'"

# Install dependencies
install:
	bundle install

# Clean generated files
clean:
	rm -rf doc/ coverage/ .yardoc/ tmp/
