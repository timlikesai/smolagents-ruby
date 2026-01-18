# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Fiber-first execution** - Unified execution model with `fiber_loop()` as the single primitive
  - `run_fiber()` - Bidirectional control for interactive execution
  - `consume_fiber()` - Handles control requests in sync mode
  - `drain_fiber_to_enumerator()` - Streaming via Fiber
- **Control requests** - `Types::ControlRequests` for human-in-the-loop workflows
  - `UserInput` - Request user input during execution
  - `Confirmation` - Request approval before dangerous actions
  - `SubAgentQuery` - Sub-agent escalation to parent
  - `Response` - Typed responses with `approve`, `deny`, `respond` factories
- **SyncBehavior** - Smart defaults for control requests in sync mode (`:default`, `:approve`, `:skip`, `:raise`)
- **Control events** - `ControlYielded`, `ControlResumed` events for observability
- **Tool control flow** - `request_input`, `request_confirmation` helpers in tools
- **ErrorDSL predicates** - `define_error :Name, predicates: { recoverable: true }` generates predicate methods
- **Events::Subscriptions** - Unified event handler DSL with `define_handler`, `configure_events`
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
- **DSL consistency** - Unified terminology across all DSL macros:
  - `attrs:` → `fields:` (matches Data.define members)
  - `builder_method` → `register_method`
  - `event_shortcut` → `define_handler`
  - `event_config` → `configure_events`
- **EventSubscriptions relocated** - Moved from `Builders::EventSubscriptions` to `Events::Subscriptions`
- **Ruby 4.0 idioms** - Endless methods sweep across 7 files
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
- **ErrorDSL** - 602 → 82 LOC (86% reduction) via metaprogramming
- **EventDSL** - 438 → 80 LOC (82% reduction) via metaprogramming
- **ToolResult** - 10 → 4 files consolidation
- **RuboCop configuration** - Reasonable defaults for builder patterns
- **YARD documentation** - Comprehensive documentation across codebase (97.31%)
- **Test coverage** - 3127 tests (up from 1269), 93.42% coverage

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
