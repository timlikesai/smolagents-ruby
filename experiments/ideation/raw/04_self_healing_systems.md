# Self-Healing Systems for AI Agents

Research into patterns and mechanisms that could enable AI agent systems to automatically recover from failures without requiring model intervention.

---

## 1. Self-Healing Patterns from Distributed Computing

### Core Patterns That Transfer to Agent Systems

Distributed systems have developed battle-tested patterns for resilience that map remarkably well to AI agent architectures.

**Pattern: Health Check + Watchdog Combination**
- Continuously monitor agent health metrics (step duration, memory usage, token consumption)
- If an agent step exceeds expected duration or resource bounds, the watchdog intervenes
- Unlike distributed systems where nodes can crash, agent "failures" often manifest as stuck states or infinite loops

**Pattern: Circuit Breaker with Graceful Degradation**
- When external tool calls fail repeatedly, stop attempting and fall back
- Already implemented in smolagents-ruby via the `CircuitBreaker` concern
- For agents: Could extend to circuit-break on specific model behaviors (repeated hallucinations, parsing failures)

**Pattern: Bulkhead Isolation**
- In ships, bulkheads contain flooding to one compartment
- For agents: Isolate tool execution from planning, so a stuck tool doesn't kill the entire agent run
- Each "compartment" (tool, planner, executor) gets resource limits and can fail independently

**AIOps Insight**: Modern systems like Elastic's observability platform use ML to detect anomalies and predict failures. An agent could run a lightweight anomaly detector on its own step patterns.

### Sources
- [GeeksforGeeks: Self-Healing Patterns for Distributed Systems](https://www.geeksforgeeks.org/computer-networks/important-self-healing-patterns-for-distributed-systems/)
- [Digital.ai: Self-Healing Software Development](https://digital.ai/catalyst-blog/self-healing-software-development/)
- [Pyramid CI: Autonomous and Self-healing Systems 2025](https://pyramidci.com/blog/technology-trends-2025-trend-2-the-emergence-of-autonomous-and-self-healing-systems/)

---

## 2. Automatic Error Recovery in Compilers and Interpreters

### Panic Mode Recovery - A Direct Analogy

Compiler error recovery offers a surprisingly apt analogy for agent recovery.

**Panic Mode Recovery**
- When a compiler encounters an error, it discards tokens until it finds a "synchronizing token" (like `;` or `}`)
- From there, it resumes parsing

**Agent Equivalent**:
```ruby
# Agent gets stuck trying to parse malformed tool output
# "Synchronizing tokens" for agents might be:
# - A clean prompt reset
# - Returning to the last successfully completed step
# - Requesting human intervention with a structured question
```

**Phrase-Level Recovery**
- Compilers perform local corrections, replacing incorrect phrases with valid ones
- For agents: If tool output is malformed, attempt to auto-correct based on expected schema before re-prompting

**Error Productions**
- Compilers add grammar rules to anticipate common errors
- For agents: Pre-define patterns of likely failure modes and their recovery paths
```ruby
ERROR_RECOVERY_PATTERNS = {
  json_parse_error: -> { request_structured_output },
  tool_not_found: -> { list_available_tools_and_retry },
  rate_limit: -> { exponential_backoff_with_jitter },
  stuck_loop: -> { summarize_and_replan }
}
```

### Sources
- [GeeksforGeeks: Error Recovery Strategies in Compiler Design](https://www.geeksforgeeks.org/error-recovery-strategies-in-compiler-design/)
- [OpenGenus: Error Recovery in Compiler Design](https://iq.opengenus.org/error-recovery-in-compiler-design/)
- [grmtools: Error Recovery](https://softdevteam.github.io/grmtools/master/book/errorrecovery.html)

---

## 3. Fuzzing and Automatic Test Generation for Agents

### The New Frontier: AI-Powered Fuzzing

As of 2025, AI-powered fuzzing has evolved significantly:
- Google's AI fuzzing found 13,000 vulnerabilities and 50,000 bugs
- Rather than random inputs, GenAI analyzes expected input formats and generates intelligent mutations

**Application to Agent Systems**:

**1. Fuzzing Agent Inputs**
- Generate adversarial user prompts that might cause loops, crashes, or unexpected behavior
- Automatically discover edge cases in tool schemas
- Test prompt injection resistance

**2. Self-Fuzzing Agents**
- An agent could periodically "fuzz" its own tool calls with slight variations
- Discover which parameter combinations cause failures
- Build a map of "known good" vs "risky" parameter spaces

**3. Prompt Fuzzing**
- The [Prompt Fuzzer](https://prompt.security/fuzzer) tool tests AI applications for resilience
- Could be integrated into agent CI/CD to catch regressions in agent behavior

**Testing Pattern**: Adaptive Seed Generation
- Model knowledge-guided prompt selection as a multi-armed bandit problem
- Dynamically select and refine test strategies based on real-time feedback

### Sources
- [CSO Online: What is AI Fuzzing](https://www.csoonline.com/article/567053/what-is-ai-fuzzing-and-why-it-may-be-the-next-big-cybersecurity-threat.html)
- [Shell Net Security: Revolutionizing Vulnerability Discovery with AI-Powered Fuzzing](https://blog.shellnetsecurity.com/posts/2025/revolutionizing-vulnerability-discovery-with-ai-powered-fuzzing/)
- [Thoughtworks: Fuzz Testing in the AI Era](https://www.thoughtworks.com/insights/blog/testing/fuzz-testing-ai-era-rediscovering-old-technique-new-challenges)
- [Prompt Security: Prompt Fuzzer](https://prompt.security/fuzzer)

---

## 4. Chaos Engineering Principles Applied to AI

### The Marriage of Chaos Engineering and ML

Chaos engineering for AI systems has emerged as a distinct discipline.

**Key Insight**: Traditional chaos engineering asks "what happens when this service fails?" For AI, we ask "what happens when the model behaves unexpectedly?"

**Fault Injection Areas for AI Agents**:
1. **Dataset-based model training** - Not applicable to inference-time agents
2. **Inference APIs** - Inject latency, timeouts, malformed responses
3. **Machine learning pipelines** - Corrupt intermediate state
4. **Decision automation frameworks** - The agent's planning/execution loop

**Chaos Experiments for Agents**:
```ruby
ChaosExperiments = [
  :random_tool_timeout,
  :corrupted_tool_output,
  :model_rate_limit_spike,
  :memory_context_corruption,
  :inconsistent_tool_availability,
  :sudden_prompt_length_limit
]
```

**AI-Enhanced Chaos**:
- ML models can analyze historical data to predict where failures are most likely
- AI can orchestrate immediate recovery steps (restart, rollback, scale)
- Systems learn from each experiment, improving anomaly detection over time

**Research Highlight**: UCL's Dynamic Systems Lab presented work at ICLR 2025 on "learning chaos in a linear way" - new approaches to understanding how complexity emerges in high-dimensional time-evolving processes.

### Sources
- [Harness: Integrating Chaos Engineering with AI/ML](https://www.harness.io/blog/integrating-chaos-engineering-with-ai-ml-proactive-failure-prediction)
- [Conf42: Chaos Engineering Meets AI 2025](https://www.conf42.com/Chaos_Engineering_2025_Chirag_Gajiwala_resilience_models_security)
- [VE3 Global: Chaos Engineering for AI](https://www.ve3.global/chaos-engineering-for-ai-how-do-we-stress-test-ai-driven-applications/)
- [DZone: Resilient AI with Chaos Engineering](https://dzone.com/articles/chaos-engineering-and-machine-learning-ensuring-re)

---

## 5. Circuit Breaker Patterns and Graceful Degradation

### The Three-State Machine

The circuit breaker pattern operates in three states:

| State | Behavior | Agent Equivalent |
|-------|----------|------------------|
| CLOSED | Normal operation | Agent executes normally |
| OPEN | Fail fast, no attempts | Skip broken tool, use fallback |
| HALF-OPEN | Limited test requests | Try tool once with timeout |

**Already Implemented in smolagents-ruby**:
- `CircuitBreaker` concern using the Stoplight gem
- Configurable threshold and cool-off periods
- Event emission on state changes
- Error categorization (circuit-breaking vs non-circuit errors)

**Enhancement Opportunities**:

1. **Per-Tool Circuit Breakers**
   - Track failure rates per tool independently
   - Allow some tools to remain available when others fail

2. **Model-Aware Circuit Breaking**
   - If a model starts producing malformed output, circuit-break on that model
   - Fallback chain already exists via `ModelFallback` concern

3. **Adaptive Thresholds**
   - Use AI/ML to dynamically adjust thresholds based on traffic patterns
   - Learn optimal cool-off times from historical data

**Graceful Degradation Strategies**:
```ruby
DegradationLevels = {
  full: -> { all_tools_available },
  reduced: -> { critical_tools_only },
  minimal: -> { final_answer_only },
  cached: -> { return_last_known_good_result }
}
```

### Sources
- [DZone: Circuit Breaker Pattern for Resilient Systems](https://dzone.com/articles/circuit-breaker-pattern-resilient-systems)
- [Talent500: Circuit Breaker Pattern in Microservices](https://talent500.com/blog/circuit-breaker-pattern-microservices-design-best-practices/)
- [Microsoft Learn: Circuit Breaker Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [ShadeCoder: Circuit Breaker Guide 2025](https://www.shadecoder.com/topics/the-circuit-breaker-pattern-a-comprehensive-guide-for-2025)

---

## 6. Automatic Retry Strategies with Exponential Backoff

### The Art of Jitter

**Core Insight**: Without jitter, retrying clients act like a "marching band" - every retry hits at the same time, causing thundering herd problems.

**Types of Jitter**:

| Strategy | Formula | Use Case |
|----------|---------|----------|
| Full Jitter | `random(0, min(cap, base * 2^attempt))` | Spreads retries widely |
| Equal Jitter | `delay/2 + random(0, delay/2)` | Always keeps some backoff |
| Decorrelated | `min(cap, random(base, prev_delay * 3))` | Natural distribution |

**Already Implemented in smolagents-ruby**:
- `RetryPolicyConfig` with default, aggressive, and conservative presets
- Exponential backoff with configurable jitter (0.5 default)
- Base interval, max interval, and max attempts

**Best Practices from AWS**:
1. Always cap maximum delay (30s is a good rule of thumb)
2. Limit maximum retries to avoid backlogs
3. Identify retryable vs non-retryable errors
4. Don't retry non-idempotent actions

**Agent-Specific Considerations**:
```ruby
# Retryable agent errors
RETRYABLE = [
  :rate_limit,
  :timeout,
  :model_overloaded,
  :transient_parse_error
]

# Non-retryable (need different intervention)
NON_RETRYABLE = [
  :context_too_long,
  :tool_not_found,
  :permission_denied,
  :stuck_in_loop  # Retry won't help!
]
```

### Sources
- [AWS Architecture Blog: Exponential Backoff And Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
- [AWS Builders Library: Timeouts, Retries and Backoff with Jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
- [Baeldung: Resilience4j Backoff Jitter](https://www.baeldung.com/resilience4j-backoff-jitter)
- [Better Stack: Exponential Backoff](https://betterstack.com/community/guides/monitoring/exponential-backoff/)

---

## 7. Rollback and Checkpoint Mechanisms

### State Recovery in Distributed Systems

**Core Concept**: Periodically save process state (checkpoint) so that upon failure, the process can roll back to a saved state and resume.

**Challenge for Agents**: Messages between processes create inter-process dependencies. In agent terms, each step depends on previous steps' outputs.

**The Domino Effect**: Without coordination, rolling back one process might force indefinite cascading rollbacks.

### Agent Checkpoint Strategy

```ruby
# Checkpoint at stable points
CheckpointStrategy = {
  after_planning: -> { save_plan_state },
  after_tool_success: -> { save_tool_result },
  after_step_complete: -> { save_step_summary },
  before_risky_operation: -> { create_restore_point }
}

# Recovery approaches
RecoveryModes = {
  # Roll back to last good state
  rollback: -> { restore_last_checkpoint },

  # Move forward from error state (requires anticipating errors)
  forward: -> { apply_error_correction },

  # Replay operations from a known point
  replay: -> { replay_from_checkpoint }
}
```

**Incremental Checkpointing**:
- Don't save entire state every time
- Only save what changed since last checkpoint
- For agents: Save delta of memory, not full context

**Coordinated Checkpointing for Multi-Agent**:
- When multiple agents collaborate, they need synchronized checkpoints
- Otherwise, rolling back one agent might leave others with inconsistent state

### Practical Implementation

```ruby
class Agent
  def run_with_checkpoints(task)
    checkpoint = nil

    each_step do |step|
      checkpoint = create_checkpoint

      begin
        execute_step(step)
      rescue RecoverableError => e
        restore_checkpoint(checkpoint)
        apply_recovery_strategy(e)
        retry
      rescue UnrecoverableError => e
        rollback_to_initial_state
        raise
      end
    end
  end
end
```

### Sources
- [ACM: Checkpointing and Rollback-Recovery for Distributed Systems](https://dl.acm.org/doi/pdf/10.5555/324493.325074)
- [GeeksforGeeks: Recovery in Distributed Systems](https://www.geeksforgeeks.org/operating-systems/recovery-in-distributed-systems/)
- [Cambridge: Checkpointing and Rollback Recovery](https://www.cambridge.org/core/books/abs/distributed-computing/checkpointing-and-rollback-recovery/1B1F6517847B18A8D59499BA3AF6179B)

---

## 8. Observability and Automatic Diagnosis Systems

### AIOps for Agent Self-Diagnosis

**Modern AIOps Capabilities**:
- Process massive amounts of logs, metrics, traces, events
- Correlate signals across distributed systems
- Enable faster root-cause analysis
- Support predictive failure detection
- Power automated remediation

**2025 Research**: A study evaluating GPT-4o, Gemini-1.5, and Mistral-small for automated RCA in chaos engineering found that LLMs can identify common failure patterns, but accuracy depends heavily on prompt engineering.

### Agent Observability Stack

```ruby
# Telemetry layers for agents
ObservabilityLayers = {
  # Raw metrics
  telemetry: [:step_duration, :token_usage, :tool_latency, :error_rate],

  # Normalized events
  events: [:step_started, :step_completed, :tool_called, :error_occurred],

  # Semantic analysis
  semantic: [:plan_coherence, :tool_relevance, :goal_progress],

  # Behavioral patterns
  patterns: [:loop_detection, :regression, :stuck_state, :drift]
}
```

**Automatic Diagnosis Pipeline**:
1. **Collect**: Gather step-by-step telemetry
2. **Normalize**: Convert to standard event format
3. **Correlate**: Link events to identify causal chains
4. **Detect**: Apply anomaly detection rules/ML
5. **Diagnose**: Determine root cause
6. **Remediate**: Trigger appropriate recovery

**Self-Diagnosis Questions**:
- Am I making progress toward the goal?
- Am I repeating the same actions?
- Are my tool calls returning useful results?
- Is my plan still valid given new information?

### Uber's M3 System (Inspiration)

Uber's observability system for thousands of microservices:
1. Begins anomaly detection without supervision by identifying metric outliers
2. Uses dependency-aware correlation to determine origin points
3. Merges metrics, traces, and logs into an event graph
4. Uses ML-based prioritization

**Adapted for Agents**: Build an "event graph" of agent actions, with ML-based prioritization of which events likely caused a failure.

### Sources
- [Springer: AIOps for Reliability - LLMs for Automated RCA](https://link.springer.com/chapter/10.1007/978-3-031-97564-6_25)
- [Elastic: Root Cause Analysis with Logs](https://www.elastic.co/observability-labs/blog/observability-logs-machine-learning-aiops)
- [Al-Kindi Publisher: Generative AI-Driven Observability for Automated RCA](https://al-kindipublisher.com/index.php/jcsts/article/view/10853)
- [ScienceLogic: Automated Root Cause Analysis](https://sciencelogic.com/articles/automated-root-cause-analysis)

---

## 9. Loop Detection and Stuck State Intervention

### The Nightmare of the Looping Agent

This is one of the most common and costly failure modes in AI agents.

**Why Agents Get Stuck**:
- Probabilistic nature of LLMs causes misinterpretation of termination signals
- Unclear stop conditions in prompts
- Tools returning consistent but unhelpful responses
- Agents "overthinking" simple tasks

### Loop Guardrails

**External Enforcement Principle**: The system running the agent, not the agent itself, must guarantee termination.

```ruby
LoopGuardrails = {
  # Hard limits
  max_steps: 50,
  max_duration: 300,  # seconds
  max_tokens: 100_000,

  # Soft limits (trigger intervention)
  repeated_action_threshold: 3,
  no_progress_steps: 5,
  tool_retry_threshold: 3
}
```

**Detection Methods**:

| Method | Description | Tradeoff |
|--------|-------------|----------|
| Action Similarity | Hash recent actions, detect repeats | May miss semantic loops |
| Output Similarity | Compare outputs for semantic similarity | More expensive but accurate |
| Goal Progress | Track explicit progress metrics | Requires defined metrics |
| Token Velocity | Tokens consumed per step | Simple but indirect |

### Intervention Strategies

```ruby
LoopInterventions = {
  # Soft interventions
  summarize_and_replan: -> {
    "Summarize what you've learned and create a new plan"
  },

  context_reset: -> {
    "Forget the last N steps and approach differently"
  },

  explicit_stop_check: -> {
    "Have you completed the task? If yes, use final_answer"
  },

  # Hard interventions
  force_answer: -> {
    "You must provide your best answer now with final_answer"
  },

  abort_with_partial: -> {
    "Return partial results and explain what's blocking completion"
  }
}
```

### Multi-Agent Loop Prevention

- Tag messages with agent ID and intent
- Implement "handshake" protocols for agent-to-agent communication
- Use persistent storage with session IDs
- Replay last known good states when primary channels fail

### Sources
- [Fix Broken AI Apps: Why AI Agents Get Stuck in Loops](https://www.fixbrokenaiapps.com/blog/ai-agents-infinite-loops)
- [Galileo: Why Multi-Agent LLM Systems Fail](https://galileo.ai/blog/multi-agent-llm-systems-fail)
- [Partnership on AI: Prioritizing Real-Time Failure Detection in AI Agents](https://partnershiponai.org/wp-content/uploads/2025/09/agents-real-time-failure-detection.pdf)
- [GitHub browser-use #191: Endless Loop Detection](https://github.com/browser-use/browser-use/issues/191)

---

## 10. Self-Correcting AI Agents

### The State of Self-Correction (2025)

**Key Insight**: Research from October 2025 shows that AI self-correction is "dangerously flawed" - models often cannot reliably verify their own outputs.

**The Fresh Context Advantage**: Using a separate model instance (or different model) to evaluate outputs performs better than self-evaluation.

### Frameworks for Self-Correction

**Agent-R Framework**:
- Combines Monte Carlo Tree Search with iterative self-training
- Agents critique their own actions and rewrite trajectories while performing
- Creates a self-improving system

**STaSC (Self-Taught Self-Correction)**:
- Small LM generates an answer, then a correction
- Fine-tuned on corrected outputs
- No human labels required

**LangGraph for Self-Correction**:
- Moves beyond linear ReAct patterns
- Supports iteration, revision, and dynamic adaptation
- True statefulness and ability to backtrack

### Practical Self-Correction Pattern

```ruby
class SelfCorrectingAgent
  def execute_with_correction(action)
    result = execute(action)

    if needs_correction?(result)
      critique = generate_critique(result)
      corrected = apply_correction(action, critique)
      execute_with_correction(corrected)  # Careful: limit recursion!
    else
      result
    end
  end

  private

  def needs_correction?(result)
    # Use separate evaluator, not self-evaluation
    evaluator.assess(result).needs_improvement?
  end
end
```

### Multi-Agent Verification

Better than self-correction: Use multiple agents with separate contexts to reduce evaluation bias.

```ruby
VerificationStrategies = {
  # Different instance evaluates
  separate_instance: -> { spawn_evaluator.assess(result) },

  # Different model evaluates
  cross_model: -> { backup_model.assess(result) },

  # Multiple critics vote
  ensemble: -> { critics.map(&:assess).majority_vote }
}
```

### Sources
- [DEV.to: Self-Correcting AI Agents](https://dev.to/louis-sanna/self-correcting-ai-agents-how-to-build-ai-that-learns-from-its-mistakes-39f1)
- [Nova Spivack: Why AI Systems Can't Catch Their Own Mistakes](https://www.novaspivack.com/technology/ai-technology/why-ai-systems-cant-catch-their-own-mistakes-and-what-to-do-about-it)
- [ActiveWizards: LangGraph for Self-Correcting AI Agents](https://activewizards.com/blog/a-deep-dive-into-langgraph-for-self-correcting-ai-agents)
- [Yohei Nakajima: Better Ways to Build Self-Improving AI Agents](https://yoheinakajima.com/better-ways-to-build-self-improving-ai-agents/)

---

## 11. Erlang/OTP Supervision: The Gold Standard

### "Let It Crash" Philosophy

Erlang's approach to fault tolerance is perhaps the most influential in the history of distributed systems.

**Core Principle**: Instead of writing defensive code for every corner case, accept that failures will happen. Separate concerns and take corrective actions.

**The Key Insight**: Modern applications have too many states to predict. When you get into an undesirable state, the best action is to reset to a fresh, well-known, correct state.

### Supervision Trees for Agents

```
                    [Agent Supervisor]
                          |
          +---------------+---------------+
          |               |               |
    [Planning]       [Execution]      [Memory]
          |               |               |
    +-----+-----+   +-----+-----+   +-----+-----+
    |           |   |           |   |           |
 [Planner] [Critic] [Tool1] [Tool2] [Store] [Index]
```

**Supervision Strategies**:

| Strategy | Behavior | Agent Use Case |
|----------|----------|----------------|
| `:one_for_one` | Restart only failed process | One tool fails, restart that tool |
| `:one_for_all` | Restart all children | Planning fails, restart everything |
| `:rest_for_one` | Restart failed + siblings after | Memory corrupted, restart memory + dependent components |

### Applying to Ruby Agent Systems

```ruby
class AgentSupervisor
  def initialize(agent)
    @agent = agent
    @restart_count = 0
    @max_restarts = 5
    @restart_window = 60  # seconds
  end

  def supervised_run(task)
    @agent.run(task)
  rescue RecoverableError => e
    handle_recoverable_failure(e)
    retry
  rescue FatalError => e
    escalate_to_parent(e)
  end

  private

  def handle_recoverable_failure(error)
    @restart_count += 1
    raise FatalError, "Too many restarts" if @restart_count > @max_restarts

    reset_agent_state
    apply_recovery_strategy(error)
  end
end
```

**Critical vs Non-Critical Components**:
- Critical (near root): Planning, goal state, core memory
- Fragile (deep in tree): Individual tool calls, caches, optimizations

### Sources
- [The Zen of Erlang](https://ferd.ca/the-zen-of-erlang.html)
- [Adopting Erlang: Supervision Trees](https://adoptingerlang.org/docs/development/supervision_trees/)
- [Medium: Building Fault-Tolerant Systems with OTP](https://medium.com/@matheuscamarques/building-fault-tolerant-systems-inside-the-otp-design-principles-of-erlang-8aed442d4a84)
- [mgasch: What I Learned from Erlang About Resiliency](https://www.mgasch.com/2019/03/crash/)

---

## 12. Watchdog Patterns for Agents

### Hardware Watchdog Concept

A watchdog timer periodically expects a "kick" from the monitored process. If the kick doesn't come (process hung), the watchdog triggers recovery.

### Software Watchdog for Agents

```ruby
class AgentWatchdog
  def initialize(agent, timeout: 30, action: :restart)
    @agent = agent
    @timeout = timeout
    @action = action
    @last_heartbeat = Time.now
  end

  def monitor
    Thread.new do
      loop do
        sleep 1
        check_health
      end
    end
  end

  def heartbeat
    @last_heartbeat = Time.now
  end

  private

  def check_health
    if Time.now - @last_heartbeat > @timeout
      take_action
    end
  end

  def take_action
    case @action
    when :restart then restart_agent
    when :escalate then notify_supervisor
    when :abort then force_terminate
    end
  end
end
```

### Integration with Agent Step Loop

```ruby
class Agent
  def run(task)
    watchdog = AgentWatchdog.new(self, timeout: 60)
    watchdog.monitor

    each_step do |step|
      watchdog.heartbeat  # Tell watchdog we're alive
      execute_step(step)
      watchdog.heartbeat  # Confirm step completed
    end
  end
end
```

### Systemd-Style Service Recovery

Systemd provides a model for service recovery that agents could adopt:
- `Restart=on-failure`: Automatically restart on failure
- `StartLimitBurst` + `StartLimitInterval`: Limit restart attempts in a time window
- Escalation: If restarts exceed limit, take stronger action (reboot system)

### Sources
- [Wikipedia: Watchdog Timer](https://en.wikipedia.org/wiki/Watchdog_timer)
- [GitHub: watchdogd - Advanced System Monitor](https://github.com/troglobit/watchdogd)
- [systemd for Administrators: Watchdog Support](http://0pointer.de/blog/projects/watchdog.html)

---

## 13. Health Check Patterns (Liveness, Readiness, Startup)

### Kubernetes-Inspired Health Probes for Agents

**Three Types of Probes**:

| Probe | Question | Agent Interpretation |
|-------|----------|---------------------|
| Liveness | Is it alive? | Is the agent process running and responsive? |
| Readiness | Can it serve? | Has the agent loaded context and is ready for tasks? |
| Startup | Has it started? | Has initial planning/warm-up completed? |

### Implementation for Agents

```ruby
class AgentHealthCheck
  def liveness
    # Fast check: Is the agent process responsive?
    {
      alive: @agent.responsive?,
      last_step_at: @agent.last_step_time,
      memory_usage: @agent.memory_mb
    }
  end

  def readiness
    # Deeper check: Can the agent handle requests?
    {
      ready: @agent.context_loaded? && @agent.tools_available?,
      context_tokens: @agent.context_size,
      available_tools: @agent.active_tools.count
    }
  end

  def startup
    # Initial check: Has warm-up completed?
    {
      started: @agent.warmed_up?,
      load_time_ms: @agent.startup_duration,
      preloaded_context: @agent.preload_complete?
    }
  end
end
```

### Traffic Management Based on Health

In Kubernetes, readiness probe failure removes a pod from the load balancer. For agents:

```ruby
AgentPool.route_to_healthy_agent(task)
# Only routes to agents where readiness probe passes
```

### Sources
- [Kubernetes: Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Google Cloud: Readiness vs Liveness Probes](https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-setting-up-health-checks-with-readiness-and-liveness-probes)
- [Better Stack: Kubernetes Health Checks](https://betterstack.com/community/guides/monitoring/kubernetes-health-checks/)

---

## 14. Creative Applications to Agent Systems

### Novel Self-Healing Mechanisms for Agents

Based on the research, here are innovative patterns specifically designed for AI agents:

#### 14.1 Semantic Circuit Breaker

Traditional circuit breakers trip on errors. A semantic circuit breaker trips on semantic failures:

```ruby
class SemanticCircuitBreaker
  def initialize
    @coherence_failures = 0
    @relevance_failures = 0
    @threshold = 3
  end

  def check(response)
    if !coherent?(response)
      @coherence_failures += 1
      trip(:coherence) if @coherence_failures >= @threshold
    end

    if !relevant_to_goal?(response)
      @relevance_failures += 1
      trip(:relevance) if @relevance_failures >= @threshold
    end
  end

  def trip(reason)
    case reason
    when :coherence then switch_to_smaller_model
    when :relevance then replan_from_scratch
    end
  end
end
```

#### 14.2 Adaptive Recovery Selection

Use ML to select the best recovery strategy based on the failure pattern:

```ruby
class AdaptiveRecovery
  def initialize
    @strategy_outcomes = Hash.new { |h, k| h[k] = [] }
  end

  def select_strategy(failure_type, context)
    # Multi-armed bandit: Explore vs exploit
    if should_explore?
      strategies.sample
    else
      best_strategy_for(failure_type, context)
    end
  end

  def record_outcome(strategy, failure_type, success)
    @strategy_outcomes[[strategy, failure_type]] << success
  end

  def best_strategy_for(failure_type, context)
    @strategy_outcomes
      .select { |k, _| k.first == failure_type }
      .max_by { |_, outcomes| outcomes.sum.to_f / outcomes.size }
      &.first&.last || default_strategy
  end
end
```

#### 14.3 Goal Progress Monitor

Detect when an agent is spinning without making progress:

```ruby
class GoalProgressMonitor
  def initialize(goal)
    @goal = goal
    @progress_history = []
    @stall_threshold = 5  # steps without progress
  end

  def update(step_result)
    progress = calculate_progress(step_result)
    @progress_history << progress

    if stalled?
      trigger_intervention
    end
  end

  def stalled?
    return false if @progress_history.size < @stall_threshold

    recent = @progress_history.last(@stall_threshold)
    recent.max - recent.min < 0.01  # No meaningful change
  end

  def trigger_intervention
    emit(Events::AgentStalled.new(
      steps_without_progress: @stall_threshold,
      current_progress: @progress_history.last,
      recommended_action: :replan
    ))
  end
end
```

#### 14.4 Memory Corruption Detection and Repair

Detect when agent memory/context has become corrupted or inconsistent:

```ruby
class MemoryIntegrityChecker
  def check(memory)
    issues = []

    # Contradiction detection
    issues << :contradiction if find_contradictions(memory)

    # Relevance decay
    issues << :irrelevant_bloat if relevance_score(memory) < 0.3

    # Circular references
    issues << :circular if detect_circular_reasoning(memory)

    repair(memory, issues) if issues.any?
  end

  def repair(memory, issues)
    case issues.first
    when :contradiction
      memory.prune_contradictory_entries
    when :irrelevant_bloat
      memory.compress_to_essential
    when :circular
      memory.break_circular_references
    end
  end
end
```

#### 14.5 Cascading Fallback Architecture

Multi-level fallback with increasing simplicity:

```ruby
class CascadingFallback
  LEVELS = [
    :retry_with_same_model,
    :retry_with_simpler_prompt,
    :fallback_to_backup_model,
    :fallback_to_cached_response,
    :fallback_to_human_handoff,
    :graceful_failure_with_explanation
  ]

  def execute_with_fallback(task)
    LEVELS.each do |level|
      result = attempt(task, level)
      return result if result.success?
    end

    FinalFallback.explain_failure(task)
  end
end
```

---

## 15. Implementation Roadmap for smolagents-ruby

### Existing Foundation

The codebase already has solid resilience primitives:
- `CircuitBreaker` with Stoplight integration
- `RetryPolicy` with exponential backoff and jitter
- `ModelFallback` for model chain traversal
- `RateLimiter` with multiple strategies
- Event system for observability

### Proposed Enhancements

**Phase 1: Detection (Low effort, high impact)**
- [ ] Loop detection middleware (action hashing, similarity detection)
- [ ] Step duration watchdog
- [ ] Goal progress tracking

**Phase 2: Intervention (Medium effort)**
- [ ] Automatic replanning on stall
- [ ] Context summarization on memory bloat
- [ ] Forced termination with partial results

**Phase 3: Adaptive Systems (Higher effort)**
- [ ] ML-based recovery strategy selection
- [ ] Semantic circuit breaker
- [ ] Checkpoint/rollback for multi-step tasks

**Phase 4: Self-Improvement (Research)**
- [ ] Learning from failure patterns
- [ ] Automatic prompt refinement based on failure modes
- [ ] Cross-agent verification systems

---

## 16. Summary: Key Principles

1. **External Enforcement**: The system, not the agent, guarantees termination and recovery
2. **Fail Fast, Recover Faster**: Circuit breakers prevent cascading failures
3. **Jitter Everything**: Randomness prevents thundering herds
4. **Checkpoint Often**: Regular state saves enable efficient rollback
5. **Observe Deeply**: Rich telemetry enables automatic diagnosis
6. **Degrade Gracefully**: Multiple fallback levels maintain partial service
7. **Let It Crash**: Sometimes resetting to known-good state beats defensive coding
8. **Verify Externally**: Self-correction is unreliable; use separate evaluators
9. **Learn from Failure**: Track recovery outcomes to improve strategies
10. **Design for Recovery**: Make recovery a first-class architectural concern
