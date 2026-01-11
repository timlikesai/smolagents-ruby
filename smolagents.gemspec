# frozen_string_literal: true

require_relative "lib/smolagents/version"

Gem::Specification.new do |spec|
  spec.name = "smolagents"
  spec.version = Smolagents::VERSION
  spec.authors = ["HuggingFace Team", "Ruby Port Contributors"]
  spec.email = ["noreply@huggingface.co"]

  spec.summary = "Ruby port of HuggingFace smolagents - AI agents with ReAct framework"
  spec.description = "A Ruby library for building AI agents that think in code. Port of the Python smolagents library."
  spec.homepage = "https://github.com/huggingface/smolagents-ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/huggingface/smolagents-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/huggingface/smolagents-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
                          lib/**/*
                          exe/*
                          LICENSE
                          README.md
                        ])
  spec.bindir = "exe"
  spec.executables = ["smolagents"]
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "base64", "~> 0.2" # Ruby 3.4+ compatibility
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "parser", "~> 3.3"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-logger", "~> 0.6"
  spec.add_dependency "tty-spinner", "~> 0.9"

  # Model client integrations (optional - install extras as needed)
  spec.add_dependency "ruby-anthropic", "~> 0.4"  # Anthropic Claude API client
  spec.add_dependency "ruby-openai", "~> 7.0"     # OpenAI API client

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rspec-mocks", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 2.26"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.2"
  spec.add_development_dependency "webmock", "~> 3.19"
  spec.add_development_dependency "yard", "~> 0.9"
end
