# Concern registrations organized by category.
#
# This file registers all concerns with the Registry, providing:
# - Metadata for introspection
# - Dependency tracking
# - Documentation generation
#
# @see Registry For the registration API
# @see Smolagents.concerns For querying registered concerns
module Smolagents
  module Concerns # rubocop:disable Metrics/ModuleLength -- registration data
    # rubocop:disable Metrics/BlockLength -- registration block
    Registry.tap do |r|
      # === Agents ===
      r.register :react_loop,
                 Smolagents::Concerns::ReActLoop,
                 category: :agents,
                 dependencies: %i[events_emitter events_consumer],
                 provides: %i[run run_fiber setup_agent tools model memory max_steps state],
                 description: "Event-driven ReAct loop for agent execution"

      r.register :react_loop_control,
                 Smolagents::Concerns::ReActLoop::Control,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[request_input request_confirmation escalate_query],
                 description: "Fiber-based bidirectional control flow"

      r.register :react_loop_repetition,
                 Smolagents::Concerns::ReActLoop::Repetition,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[check_repetition repetition_detected?],
                 description: "Loop detection for stuck agents"

      r.register :planning,
                 Smolagents::Concerns::Planning,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[current_plan plan_context planning_interval],
                 description: "Pre-Act planning with periodic updates"

      r.register :evaluation,
                 Smolagents::Concerns::Evaluation,
                 category: :agents,
                 dependencies: [:react_loop],
                 provides: %i[evaluate_progress parse_evaluation],
                 description: "Metacognition phase for progress assessment"

      r.register :self_refine,
                 Smolagents::Concerns::SelfRefine,
                 category: :agents,
                 provides: %i[refine_answer should_refine?],
                 description: "Iterative answer improvement loop"

      r.register :reflection_memory,
                 Smolagents::Concerns::ReflectionMemory,
                 category: :agents,
                 provides: %i[store_reflection retrieve_reflections],
                 description: "Cross-run learning and memory"

      r.register :managed_agents,
                 Smolagents::Concerns::ManagedAgents,
                 category: :agents,
                 provides: %i[managed_agents delegate_to_agent],
                 description: "Sub-agent delegation and orchestration"

      r.register :async_tools,
                 Smolagents::Concerns::AsyncTools,
                 category: :agents,
                 provides: %i[parallel_execute await_all],
                 description: "Parallel tool execution"

      r.register :early_yield,
                 Smolagents::Concerns::EarlyYield,
                 category: :agents,
                 provides: %i[yield_early speculative_execute],
                 description: "Speculative execution with early results"

      # === Resilience ===
      r.register :circuit_breaker,
                 Smolagents::Concerns::CircuitBreaker,
                 category: :resilience,
                 provides: %i[with_circuit_breaker],
                 description: "Fail-fast circuit breaker pattern"

      r.register :rate_limiter,
                 Smolagents::Concerns::RateLimiter,
                 category: :resilience,
                 provides: %i[enforce_rate_limit! rate_limit_ok? retry_after],
                 description: "API rate limiting with configurable cooldown"

      r.register :resilience,
                 Smolagents::Concerns::Resilience,
                 category: :resilience,
                 dependencies: %i[circuit_breaker rate_limiter],
                 provides: [:resilient_call],
                 description: "Combined rate limiting and circuit breaking"

      r.register :retry_policy,
                 Smolagents::Concerns::RetryPolicy,
                 category: :resilience,
                 provides: %i[build_policy delay_for_attempt should_retry?],
                 description: "Configurable retry policies with exponential backoff"

      r.register :retryable,
                 Smolagents::Concerns::Retryable,
                 category: :resilience,
                 dependencies: [:retry_policy],
                 provides: %i[with_retry retryable_errors],
                 description: "Block execution with retry logic"

      r.register :tool_retry,
                 Smolagents::Concerns::ToolRetry,
                 category: :resilience,
                 dependencies: [:retryable],
                 provides: %i[retry_tool_execution tool_retry_policy],
                 description: "Tool-specific retry with backoff"

      # === Tools ===
      r.register :tool_schema,
                 Smolagents::Concerns::ToolSchema,
                 category: :tools,
                 provides: %i[tool_properties tool_required_fields json_schema_type],
                 description: "Tool schema conversion utilities"

      r.register :mcp,
                 Smolagents::Concerns::Mcp,
                 category: :tools,
                 provides: %i[mcp_tool_definition execute_mcp_call],
                 description: "Model Context Protocol support"

      # === API ===
      r.register :api_key,
                 Smolagents::Concerns::ApiKey,
                 category: :api,
                 provides: %i[require_api_key optional_api_key configure_provider],
                 description: "API key resolution from args or environment"

      r.register :http,
                 Smolagents::Concerns::Http,
                 category: :api,
                 provides: %i[get post safe_api_call],
                 description: "HTTP client with error handling"

      r.register :api_client,
                 Smolagents::Concerns::ApiClient,
                 category: :api,
                 dependencies: %i[http api_key],
                 provides: %i[configure_client base_url headers],
                 description: "Configured API client pattern"

      # === Parsing ===
      r.register :json_parsing,
                 Smolagents::Concerns::Json,
                 category: :parsing,
                 provides: %i[extract_json parse_json_safely extract_code_block],
                 description: "JSON extraction from LLM responses"

      r.register :xml_parsing,
                 Smolagents::Concerns::Xml,
                 category: :parsing,
                 provides: %i[extract_xml parse_xml_safely],
                 description: "XML extraction and parsing"

      r.register :html_parsing,
                 Smolagents::Concerns::Html,
                 category: :parsing,
                 provides: %i[extract_text extract_links simplify_html],
                 description: "HTML content extraction"

      # === Execution ===
      r.register :code_execution,
                 Smolagents::Concerns::CodeExecution,
                 category: :execution,
                 provides: %i[execute_code build_execution_context],
                 description: "Sandboxed Ruby code execution"

      r.register :step_execution,
                 Smolagents::Concerns::StepExecution,
                 category: :execution,
                 provides: %i[execute_step step_duration],
                 description: "Step timing and execution wrapper"

      r.register :code_generation,
                 Smolagents::Concerns::CodeGeneration,
                 category: :execution,
                 provides: %i[generate_code extract_code],
                 description: "Code generation from model output"

      r.register :code_parsing,
                 Smolagents::Concerns::CodeParsing,
                 category: :execution,
                 provides: %i[parse_action extract_tool_calls],
                 description: "Parse actions from model output"

      # === Monitoring ===
      r.register :auditable,
                 Smolagents::Concerns::Auditable,
                 category: :monitoring,
                 provides: %i[audit_log record_audit],
                 description: "Audit logging for agent actions"

      r.register :monitorable,
                 Smolagents::Concerns::Monitorable,
                 category: :monitoring,
                 dependencies: [:events_emitter],
                 provides: %i[monitor_step step_monitors],
                 description: "Step timing and monitoring"

      # === Validation ===
      r.register :execution_oracle,
                 Smolagents::Concerns::ExecutionOracle,
                 category: :validation,
                 provides: %i[validate_execution score_confidence generate_suggestions],
                 description: "External validation of agent execution"

      r.register :goal_drift,
                 Smolagents::Concerns::GoalDrift,
                 category: :validation,
                 provides: %i[detect_drift drift_score generate_guidance],
                 description: "Goal drift detection and correction"

      # === Sandbox ===
      r.register :ruby_safety,
                 Smolagents::Concerns::RubySafety,
                 category: :sandbox,
                 provides: %i[safe_eval allowed_methods blocked_constants],
                 description: "Ruby code safety validation"

      # === Formatting ===
      r.register :result_formatting,
                 Smolagents::Concerns::ResultFormatting,
                 category: :formatting,
                 provides: %i[format_result format_tool_output],
                 description: "Tool result formatting"

      r.register :message_formatting,
                 Smolagents::Concerns::MessageFormatting,
                 category: :formatting,
                 provides: %i[format_messages format_chat_message],
                 description: "Chat message formatting"

      # === Models ===
      r.register :model_health,
                 Smolagents::Concerns::ModelHealth,
                 category: :models,
                 provides: %i[health_status healthy? degraded?],
                 description: "Model health monitoring"

      r.register :model_reliability,
                 Smolagents::Concerns::ModelReliability,
                 category: :models,
                 dependencies: %i[retry_policy events],
                 provides: %i[reliable_generate with_fallback],
                 description: "Model reliability with retry and fallback"

      r.register :request_queue,
                 Smolagents::Concerns::RequestQueue,
                 category: :models,
                 provides: %i[enqueue process_queue queue_size],
                 description: "Request queuing for rate limiting"

      # === Events ===
      r.register :events_emitter,
                 Smolagents::Events::Emitter,
                 category: :events,
                 provides: %i[emit_event on_event],
                 description: "Event emission for pub/sub"

      r.register :events_consumer,
                 Smolagents::Events::Consumer,
                 category: :events,
                 provides: %i[subscribe consume_events],
                 description: "Event subscription and consumption"

      # === Support ===
      r.register :gem_loader,
                 Smolagents::Concerns::GemLoader,
                 category: :support,
                 provides: %i[require_gem gem_available?],
                 description: "Lazy gem loading with availability checks"

      r.register :browser_mode,
                 Smolagents::Concerns::Support::BrowserMode,
                 category: :support,
                 provides: %i[headless? browser_type],
                 description: "Browser mode configuration"
    end
    # rubocop:enable Metrics/BlockLength
  end
end
