# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.24.0] - 2025-01-11

### Added
- Concerns-based architecture with 25 composable modules
- CodeAgent and ToolCallingAgent base classes
- Specialized agents: Researcher, FactChecker, Calculator, DataAnalyst, WebScraper, Transcriber, Assistant
- 10 built-in tools: DuckDuckGo, Bing, Brave, Google search, Wikipedia, VisitWebpage, RubyInterpreter, FinalAnswer, UserInput, SpeechToText
- ToolResult with chainable Enumerable interface
- Ruby DSL for prompts (replaces YAML templates)
- Circuit breaker and rate limiting for API resilience
- CLI with `smolagents run`, `smolagents tools`, `smolagents models`
- OpenAI and Anthropic model integrations

### Changed
- Requires Ruby 4.0+
- Tools have unique names (google_search, brave_search, bing_search, duckduckgo_search)

### Removed
- YAML prompt templates (replaced with Ruby Prompts module)
- Monitoring directory (functionality moved to AgentLogger and Monitorable concern)
