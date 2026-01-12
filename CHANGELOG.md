# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2026-01-12

Initial release of smolagents-ruby, a complete Ruby port of HuggingFace's smolagents Python library.

### Added
- CodeAgent and ToolCallingAgent implementations
- Specialized agents: Researcher, FactChecker, Calculator, DataAnalyst, WebScraper, Transcriber, Assistant
- 10 built-in tools: DuckDuckGo, Bing, Brave, Google search, Wikipedia, VisitWebpage, RubyInterpreter, FinalAnswer, UserInput, SpeechToText
- ToolResult with chainable Enumerable interface and pattern matching
- Agent persistence with save/load functionality (API keys never serialized)
- RactorExecutor for true memory isolation
- Circuit breaker and rate limiting for API resilience
- Concerns-based architecture with 25 composable modules
- Ruby DSL for prompts
- CLI with `smolagents run`, `smolagents tools`, `smolagents models`
- OpenAI, Anthropic, and LiteLLM model integrations
- MCP (Model Context Protocol) support
- 1174 tests with comprehensive coverage

### Notes
- Requires Ruby 4.0+
- Port from Python smolagents with Ruby-idiomatic enhancements
