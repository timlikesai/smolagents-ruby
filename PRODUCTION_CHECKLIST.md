# Production Deployment Checklist for smolagents-ruby

A comprehensive checklist for deploying smolagents-ruby to production environments. Work through each section methodically, verifying requirements before proceeding to the next phase.

## 1. Configuration

Configuration must be frozen and validated before deployment.

### Initialization & Freezing
- [ ] All configuration values are explicitly set (no reliance on defaults)
- [ ] Configuration objects are frozen using `.freeze` before agent instantiation
- [ ] SMOLAGENTS_QUIET=1 environment variable set in production
- [ ] Configuration loading happens once at application startup, not per-request
- [ ] Verify no configuration mutations occur after agent initialization

### LLM & Model Configuration
- [ ] Model IDs/endpoints are explicitly set and validated
- [ ] API keys are loaded from secure secret management (not hardcoded)
- [ ] Temperature, top_p, and other sampling parameters are tuned for your use case
- [ ] Model timeout is set (recommend 30-60 seconds for API calls)
- [ ] Fallback models are configured for resilience
- [ ] Max completion tokens are set appropriately for your domain

### Agent Behavior Limits
- [ ] `max_steps` is set (recommend 10-20 for production agents)
- [ ] `max_execution_time` is set (recommend 5-10 minutes max)
- [ ] Planning interval is tuned for your use case (if enabled)
- [ ] Memory budgets are set (token limits for agent memory)
- [ ] Step timeouts prevent runaway execution

### Network & External Communication
- [ ] HTTP client timeouts configured (connect, read, write)
- [ ] HTTP connection pool size is set appropriately for concurrency
- [ ] DNS resolution timeouts are explicit
- [ ] Retry policies are configured with exponential backoff
- [ ] Circuit breaker thresholds are tuned for your failure tolerance

### Tool & Executor Configuration
- [ ] Tool execution timeouts are set per tool (if applicable)
- [ ] Ractor isolation timeouts are configured (if using Ractor executors)
- [ ] Thread pool size is tuned for your deployment environment
- [ ] Executor strategy matches your environment (threaded vs. Ractor vs. process)

---

## 2. Observability

Comprehensive visibility into agent operations is critical for production reliability.

### Structured Logging
- [ ] Structured logging is enabled (JSON or similar format)
- [ ] Log level is set appropriately (INFO for production, DEBUG for troubleshooting)
- [ ] Agent step details are logged with unique request IDs
- [ ] Tool execution logs include timing and parameters
- [ ] Model API calls are logged with token usage and latency
- [ ] Error logs include full stack traces and context

### Event Streaming & Monitoring
- [ ] Event subscribers are configured for critical event types
  - [ ] `step_complete` - for tracking agent progress
  - [ ] `error` - for alert triggers
  - [ ] `model_generate_completed` - for token/cost tracking
  - [ ] `tool_call` - for audit trails
- [ ] Events are streamed to logging backend (not discarded)
- [ ] Event timing information is captured and analyzed

### OpenTelemetry & Metrics
- [ ] OpenTelemetry traces are enabled if using Spans
- [ ] Trace exporter is configured (Jaeger, Datadog, etc.)
- [ ] Key metrics are exported
  - [ ] Agent execution duration
  - [ ] Steps per execution
  - [ ] Tool call count and duration
  - [ ] Model API latency and token usage
  - [ ] Error rates and types
- [ ] Metrics are sent to metrics backend (Prometheus, Datadog, etc.)

### Error & Exception Tracking
- [ ] Error tracking service is configured (Sentry, Rollbar, Honeybadger, etc.)
- [ ] Error context includes request ID, user ID, and agent configuration
- [ ] Stack traces are captured and transmitted
- [ ] Error grouping is configured to avoid alert spam
- [ ] Alerts are configured for critical error rates or patterns

### Secret & Sensitive Data Redaction
- [ ] Secret redaction is enabled in logging
- [ ] API keys are masked in logs and traces
- [ ] User data is redacted from agent prompts before logging
- [ ] PII (email, phone, SSN, etc.) is masked in logs
- [ ] Model responses with sensitive data are redacted
- [ ] Redaction patterns are tested and verified

---

## 3. Resource Management

Prevent resource exhaustion and ensure graceful degradation under load.

### Connection & Thread Pooling
- [ ] Database connection pool size is set (if using database tools)
- [ ] HTTP connection pool size matches expected concurrency
- [ ] Connection pool timeout is set to prevent hanging requests
- [ ] Thread pool size is tuned for CPU count and workload
  - For CPU-bound: thread_count = cpu_count
  - For I/O-bound: thread_count = cpu_count * 2-4
- [ ] Thread pool queue size has a reasonable limit
- [ ] Ractor pool size is tuned if using Ractor executors

### Memory Management
- [ ] Agent memory budgets are set (token limits for history)
- [ ] Memory budgets are conservative (not consuming all available RAM)
- [ ] Conversation history trimming is enabled and tested
- [ ] Large tool outputs are truncated if necessary
- [ ] Memory usage is monitored and alerted on during execution

### Operation Timeouts
- [ ] Model generation timeout: 30-60 seconds
- [ ] Tool execution timeout: varies by tool, but minimum 5 seconds
- [ ] Ractor isolation timeout: 30-60 seconds
- [ ] Total agent execution timeout: 5-10 minutes
- [ ] Database operation timeout: 10-30 seconds
- [ ] Graceful timeout handling (cleanup, response formatting)

### Authorized Imports & Code Safety
- [ ] `authorized_imports` whitelist is defined and minimal
- [ ] Only necessary standard libraries are included
- [ ] Third-party dependencies in `authorized_imports` are vetted
- [ ] Dangerous modules (File, Kernel, system calls) are excluded
- [ ] Whitelist is reviewed and updated with each deployment
- [ ] Test that AST validator rejects non-whitelisted imports

---

## 4. Security

Protect the agent system from abuse and unauthorized access.

### Tool & Import Whitelisting
- [ ] `authorized_imports` whitelist is configured and frozen
- [ ] Tool registry only includes approved tools
- [ ] Tool inputs are validated and sanitized
- [ ] Tool output size limits are enforced
- [ ] No file system access unless explicitly required and scoped
- [ ] No arbitrary code execution capabilities

### Secret & Credential Management
- [ ] API keys are stored in secure secret manager (Vault, AWS Secrets Manager, etc.)
- [ ] Secrets are not logged, even in debug mode
- [ ] Secret rotation is tested and documented
- [ ] Environment variables with secrets are not exposed in logs
- [ ] API key scope is minimal (only what each model/tool needs)

### SSRF & Outbound Request Protection
- [ ] SSRF protection is configured if tools make HTTP requests
- [ ] Blocked IP ranges include:
  - [ ] 127.0.0.1/8 (localhost)
  - [ ] 169.254.0.0/16 (metadata servers)
  - [ ] 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (private networks)
  - [ ] Cloud provider metadata endpoints
- [ ] Allowed domains/IPs are explicitly configured
- [ ] DNS rebinding protection is enabled
- [ ] SSRF rules are tested with attempted bypass payloads

### AST Validator & Code Execution Safety
- [ ] AST validator is configured with strict rules
- [ ] Dangerous node types are blocked (eval, system, exec, etc.)
- [ ] Loop limits are set to prevent infinite loops
- [ ] Recursion depth limits are enforced
- [ ] Validator rules are reviewed before each deployment

### Tool Permissions & Data Access
- [ ] Each tool has minimal required permissions
- [ ] Tool input validation rejects oversized/malformed requests
- [ ] Tool output is truncated if excessively large
- [ ] Tools are audited for information disclosure (timing attacks, etc.)
- [ ] Sensitive operations require additional authorization
- [ ] Tool execution is rate-limited if applicable

---

## 5. Multi-Process Environments

Ensure agents work reliably across multiple processes and instances.

### Distributed Circuit Breaker State
- [ ] Redis backend is configured for Stoplight circuit breakers
- [ ] Redis connection is pooled and resilient (with reconnection)
- [ ] Redis failover strategy is defined (degrade gracefully without Redis)
- [ ] Circuit breaker key namespacing prevents collisions
- [ ] Circuit breaker state is monitored across all processes

### Configuration Immutability
- [ ] Configuration is frozen at initialization time
- [ ] Verify `.freeze` prevents any mutations after startup
- [ ] Configuration changes require application restart
- [ ] No per-request configuration changes are possible
- [ ] Configuration state is validated to be identical across processes

### Agent Instance Management
- [ ] Agents are instantiated once per process, not per-request
- [ ] Agent instances are stored in a per-process cache/registry
- [ ] If agents must be created per-request, ensure state isolation
- [ ] Test agent instance creation with concurrent requests
- [ ] Verify no state leakage between concurrent executions
- [ ] Thread safety of agent components is verified

### Request Isolation
- [ ] Each request has a unique request ID for tracing
- [ ] Agent execution state is isolated per request
- [ ] No global mutable state is shared between requests
- [ ] Memory is properly released after each request completes
- [ ] Long-running agents don't block other requests

---

## 6. Testing

Comprehensive testing validates production readiness.

### Test Suite Execution
- [ ] Full test suite passes: `rake spec`
- [ ] CI pipeline passes: `rake ci`
- [ ] No skipped tests (all `.skip` markers removed)
- [ ] Test coverage is adequate (aim for >80% for critical paths)
- [ ] All tests pass with production configuration

### Integration & Acceptance Testing
- [ ] End-to-end agent execution tests pass
- [ ] Tests with production-like data volume and complexity
- [ ] Tests with production model instances (or mocked equivalents)
- [ ] Tests with actual tool implementations (or realistic mocks)
- [ ] Tests with production data patterns and edge cases

### Error Handling & Recovery
- [ ] Network error paths are tested (timeout, connection refused, etc.)
- [ ] API error responses are handled gracefully
- [ ] Tool execution failures are caught and logged
- [ ] Circuit breaker activation and recovery are tested
- [ ] Fallback models are exercised and verified
- [ ] Graceful degradation under resource constraints is tested

### Load & Performance Testing
- [ ] Load test with expected peak concurrency
- [ ] Monitor memory, CPU, and connection pool during load
- [ ] Verify response times are within SLAs
- [ ] Identify and address any resource leaks
- [ ] Test with production-realistic tool latencies
- [ ] Verify timeout settings prevent long-running requests

### Security Testing
- [ ] Attempt unauthorized tool access (denied correctly)
- [ ] Test SSRF protection with bypass attempts
- [ ] Verify secret redaction in logs
- [ ] Test AST validator rejects dangerous code
- [ ] Verify API key scope is enforced
- [ ] Load test to identify DoS vulnerabilities

### Configuration Validation
- [ ] Configuration loading succeeds in production environment
- [ ] All required configuration values are present
- [ ] Configuration freeze prevents mutation
- [ ] Fallback defaults are tested
- [ ] Configuration error messages are clear

---

## Pre-Deployment Sign-Off

- [ ] All checklist items verified and signed off
- [ ] Rollback plan is documented
- [ ] Monitoring dashboards are created
- [ ] On-call escalation procedures are documented
- [ ] Deployment window is scheduled with stakeholders
- [ ] All environment variables and secrets are prepared
- [ ] Health check endpoints are configured and tested

## Rollback Plan

Document your rollback strategy:
- Mechanism for reverting to previous version
- Time to rollback (target SLA)
- Communication procedures
- Data consistency verification

## Post-Deployment Verification (First 24 Hours)

- [ ] No increased error rates
- [ ] Agent execution times are within baseline
- [ ] Memory usage is stable
- [ ] Circuit breakers are not persistently open
- [ ] All configured tools are functioning
- [ ] Logging and monitoring are capturing data
- [ ] No unusual resource consumption

---

## Useful Commands

```bash
# Run full test suite
rake spec

# Run fast tests only (skip integration tests)
rake spec_fast

# Run full CI pipeline (linting + tests)
rake ci

# Prepare for commit (auto-fix + stage + verify)
rake commit_prep

# Check code style
bundle exec rubocop

# Run specific test
bundle exec rspec spec/path/to/test_spec.rb
```

---

## Configuration Example

```ruby
# config/initializers/smolagents.rb (or similar)

CONFIG = {
  quiet: true,  # Set SMOLAGENTS_QUIET=1 instead for env var
  max_steps: 15,
  max_execution_time: 600,  # 10 minutes

  model: {
    id: ENV['LLM_MODEL_ID'],
    temperature: 0.7,
    timeout: 45,
    retry: { max_attempts: 3 }
  },

  http: {
    timeout: 30,
    pool_size: 20
  },

  circuit_breaker: {
    redis_backend: true,
    redis_url: ENV['REDIS_URL'],
    threshold: 5,
    timeout: 60
  },

  security: {
    authorized_imports: [
      'Base64', 'JSON', 'Time', 'Date',
      'Set', 'StringIO'
    ],
    ssrf_protection: true,
    secret_redaction: true
  },

  observability: {
    structured_logging: true,
    error_tracking: ENV['SENTRY_DSN'],
    opentelemetry: true
  }
}.freeze

AGENT = Smolagents.agent
  .model { OpenAIModel.new(CONFIG[:model]) }
  .tools(:web_search, :calculator)
  .max_steps(CONFIG[:max_steps])
  .build
  .freeze
```

---

## References

- See **CLAUDE.md** for configuration DSL reference
- See **AGENTS.md** for contributor guidance
- See **PLAN.md** for architecture decisions
