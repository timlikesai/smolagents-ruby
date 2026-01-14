source "https://rubygems.org"

# Runtime dependencies from gemspec
gemspec

# Development dependencies (alphabetically sorted)
group :development do
  gem "irb", "~> 1.15"
  gem "rake", "~> 13.0"
  gem "rdoc", "~> 6.7"
  gem "redcarpet", "~> 3.6"
  gem "yard", "~> 0.9"
end

group :test do
  gem "parallel_tests", "~> 4.7"
  gem "rspec", "~> 3.12"
  gem "rspec-mocks", "~> 3.12"
  gem "simplecov", "~> 0.22"
  gem "timecop", "~> 0.9"
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
end

group :lint do
  gem "rubocop", "~> 1.82"
  gem "rubocop-performance", "~> 1.26"
  gem "rubocop-rspec", "~> 3.9"
end

# Optional model integrations (install for testing)
group :development, :test do
  gem "mcp", "~> 0.5"
  gem "ruby-anthropic", "~> 0.4"
  gem "ruby-openai", "~> 7.0"
end
