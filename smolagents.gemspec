require_relative "lib/smolagents/version"

Gem::Specification.new do |spec|
  spec.name = "smolagents"
  spec.version = Smolagents::VERSION
  spec.authors = ["HuggingFace Team", "Ruby Port Contributors"]
  spec.email = ["noreply@huggingface.co"]

  spec.summary = "Ruby port of HuggingFace smolagents - AI agents with ReAct framework"
  spec.description = "A Ruby library for building AI agents that think in code. Port of the Python smolagents library."
  spec.homepage = "https://github.com/timlikesai/smolagents-ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/timlikesai/smolagents-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/timlikesai/smolagents-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

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
  spec.add_dependency "base64", "~> 0.2" # Extracted from stdlib
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "logger", "~> 1.6" # Extracted from stdlib in Ruby 4.0
  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "reverse_markdown", "~> 2.1" # HTML to Markdown conversion
  spec.add_dependency "stoplight", "~> 4.0"
  spec.add_dependency "thor", "~> 1.3"

  # Model client integrations are optional - install the ones you need:
  # - gem 'ruby-openai', '~> 7.0' for OpenAI models
  # - gem 'ruby-anthropic', '~> 0.4' for Anthropic models
  # - gem 'mcp', '~> 0.5' for Model Context Protocol (MCP) server integration
  #
  # Development dependencies are in Gemfile (per Gemspec/DevelopmentDependencies cop)
end
