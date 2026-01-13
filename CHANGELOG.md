# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **DSL.Builder factory** - Create custom builders with validation, help, and freeze support
- **Builder validation** - All builders validate configuration at setter time with helpful error messages
- **Builder introspection** - `.help` method on all builders for REPL-friendly development
- **Builder freeze** - `.freeze!` method locks configuration for production safety
- **Pattern matching** - Full Data.define support in all builders and types
- **ExecutionOutcome types** - Hierarchical outcome types for agent planning
- **Instrumentation** - `Instrumentation.observe()` for outcome-based operations
- **LoggingSubscriber** - Simple logging output for telemetry events
- **Model reliability DSL** - `.with_retry()`, `.with_fallback()`, `.with_health_check()`, `.with_queue()`
- **Local model factories** - `OpenAIModel.lm_studio()`, `.ollama()`, `.llama_cpp()`, `.vllm()`
- **Testing framework** - `Testing::ModelBenchmark` for tiered model evaluation

### Changed
- **Module reorganization** - Moved utilities to focused modules:
  - `Logging::AgentLogger` (from `Utilities::AgentLogger`)
  - `Security::PromptSanitizer` (from `Utilities::PromptSanitizer`)
  - `Security::SecretRedactor` (from `Utilities::SecretRedactor`)
  - `Telemetry::Instrumentation` (from `Utilities::Instrumentation`)
  - `Http::UserAgent` (from `UserAgent`)
  - `Types::AgentMemory` (from `Agents::Memory`)
- **All builders** - Converted to Data.define for immutability and pattern matching
- **All step types** - Converted to Data.define (ActionStep, TaskStep, PlanningStep, FinalAnswerStep)
- **Configuration** - Converted to Data.define with validation

### Improved
- **RuboCop configuration** - Reasonable defaults for builder patterns
- **YARD documentation** - Comprehensive documentation across codebase
- **Test coverage** - 1825 tests (up from 1269)

### Removed
- Stale planning documents (consolidated into CLAUDE.md)
- Legacy re-exports (forward-only development)

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
- 1269 tests with comprehensive coverage

### Notes
- Requires Ruby 4.0+
- Port from Python smolagents with Ruby-idiomatic enhancements
