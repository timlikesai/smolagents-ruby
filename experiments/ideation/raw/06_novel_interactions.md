# Novel Interaction Patterns: Agent-Model Collaboration

> "The framework should be a collaborative partner, not just a runtime environment."

This document explores unconventional, creative interaction patterns between the smolagents-ruby framework and the language models it orchestrates. Drawing from diverse fields including educational psychology, game design, human-computer interaction, and cognitive science, we imagine a future where agents and models work together in sophisticated, adaptive ways.

---

## Table of Contents

1. [Adaptive Prompting](#1-adaptive-prompting)
2. [Example Injection](#2-example-injection)
3. [Scaffolding](#3-scaffolding)
4. [Guardrails](#4-guardrails)
5. [Feedback Loops](#5-feedback-loops)
6. [Metacognition](#6-metacognition)
7. [Progressive Complexity](#7-progressive-complexity)
8. [Collaborative Problem Solving](#8-collaborative-problem-solving)
9. [Wild Ideas](#9-wild-ideas)

---

## 1. Adaptive Prompting

### The Vision

What if the system detected model capability and adjusted prompts dynamically?

Different models have vastly different capabilities, context windows, reasoning styles, and failure modes. A prompt optimized for GPT-4 might overwhelm a smaller model, while one designed for a 7B model might leave GPT-4 underutilized. The framework should adapt.

### Research Inspiration

**Zone of Proximal Development (Vygotsky)**: Learning occurs best in the "zone" between what learners can do alone and what they can achieve with support. Apply this to models--provide support calibrated to capability.

> "The ZPD refers to the 'sweet spot' of learning, the space between what a learner can do independently and what they can accomplish with some guidance."
> -- [Simply Psychology](https://www.simplypsychology.org/zone-of-proximal-development.html)

**Cognitive Load Theory**: By replacing complex interfaces with conversational input, LLMs reduce cognitive load. But the prompts themselves carry cognitive load for the model. Minimize extraneous load, maximize germane load.

> "Research in human-computer interaction and cognitive psychology establishes how information presentation affects processing efficiency."
> -- [Prompt Engineering Guide](https://www.promptingguide.ai/research/rag)

### Concrete Ideas

#### 1.1 Capability Probing

```ruby
# Before the main task, probe the model
Smolagents.agent
  .model { some_model }
  .with_capability_probe  # Tests: reasoning depth, context retention, tool use
  .adapt_prompts_to_capability
  .build
```

The probe could be a quick battery of tests:
- Can it follow a 3-step logical chain?
- Does it lose context after N tokens?
- Can it correctly format tool calls?

Results feed into a `CapabilityProfile` that shapes all subsequent prompts.

#### 1.2 Progressive Prompt Enhancement

```ruby
class AdaptivePromptBuilder
  def for_model(capability_profile)
    base = "Search for information about #{topic}"

    case capability_profile.reasoning_level
    when :basic
      base
    when :intermediate
      base + "\n\nThink step by step about what to search for."
    when :advanced
      base + "\n\nConsider multiple search strategies. " +
             "Evaluate which would yield the most relevant results. " +
             "Explain your reasoning."
    end
  end
end
```

#### 1.3 Dynamic Context Windowing

For models with limited context, automatically:
- Summarize earlier conversation turns
- Prioritize recent/relevant context
- Use progressive disclosure (show more detail only when needed)

#### 1.4 Model Fingerprinting

Build a database of model characteristics:

```ruby
ModelProfile = Data.define(
  :name,
  :context_window,
  :reasoning_depth,        # 1-5 scale
  :tool_calling_style,     # :native, :json, :code
  :common_failure_modes,   # [:context_drift, :hallucination, :format_errors]
  :optimal_temperature_range
)
```

The framework learns which prompting strategies work best for each fingerprint.

---

## 2. Example Injection

### The Vision

What if errors triggered relevant examples to be injected into context?

When a model makes a mistake, it often lacks the right mental model. Providing a worked example of the correct approach can unlock understanding.

### Research Inspiration

**Worked Example Effect (Cognitive Load Theory)**: Examples provide scaffolding that reduces cognitive load during skill acquisition.

> "Worked examples improve learning by reducing cognitive load during skill acquisition, and 'is one of the earliest and probably the best known cognitive load reducing technique'."
> -- [Worked-example effect - Wikipedia](https://en.wikipedia.org/wiki/Worked-example_effect)

**Cognitive Apprenticeship**: Learning through observation of expert practice, with modeling, coaching, and scaffolding.

> "Cognitive apprenticeship is a model of instruction that works to make thinking visible."
> -- [AFT Cognitive Apprenticeship](https://www.aft.org/ae/winter1991/collins_brown_holum)

### Concrete Ideas

#### 2.1 Error-Triggered Example Bank

```ruby
class ExampleBank
  EXAMPLES = {
    tool_format_error: {
      pattern: /Invalid tool call format/,
      example: <<~EXAMPLE
        CORRECT TOOL CALL FORMAT:

        When you want to search, write:
        search(query: "your search terms")

        NOT:
        search("your search terms")  # Wrong - missing parameter name
        search query="..."           # Wrong - missing parentheses
      EXAMPLE
    },
    reasoning_incomplete: {
      pattern: /jumped to conclusion|missing steps/,
      example: <<~EXAMPLE
        COMPLETE REASONING EXAMPLE:

        Task: Find the population of Tokyo

        Step 1: I need to search for Tokyo population data
        Step 2: search(query: "Tokyo population 2024")
        Step 3: The search returns 13.96 million for Tokyo proper
        Step 4: I should clarify if this is Tokyo proper or Greater Tokyo
        Step 5: search(query: "Greater Tokyo metropolitan area population")
        Step 6: Greater Tokyo has 37.4 million people

        final_answer(answer: "Tokyo proper: 13.96M, Greater Tokyo: 37.4M")
      EXAMPLE
    }
  }

  def inject_for_error(error_type)
    EXAMPLES[error_type]&.dig(:example)
  end
end
```

#### 2.2 Progressive Example Complexity

Start with simple examples, escalate to complex ones if errors persist:

```ruby
class ExampleEscalator
  def example_for_attempt(error_type, attempt_number)
    examples = EXAMPLES_BY_COMPLEXITY[error_type]
    examples[attempt_number.clamp(0, examples.length - 1)]
  end
end
```

#### 2.3 Contrastive Examples

Show both correct AND incorrect examples, with explicit contrast:

```ruby
CONTRASTIVE_EXAMPLE = <<~EXAMPLE
  WRONG WAY (common mistake):
  search("population")  # Too vague, will get irrelevant results

  RIGHT WAY:
  search(query: "Japan population 2024 census data")  # Specific, dated, sourced
EXAMPLE
```

#### 2.4 In-Context Learning Injection

When a model fails at a task type, dynamically inject a successful example from history:

```ruby
class HistoricalExampleInjector
  def inject_similar_success(failed_task)
    similar = find_similar_successful_task(failed_task)
    <<~INJECTION
      Here's how a similar task was successfully completed:

      Task: #{similar.task}
      Solution:
      #{similar.solution_trace}

      Now apply this approach to your current task.
    INJECTION
  end
end
```

---

## 3. Scaffolding

### The Vision

What if complex tasks were automatically broken down?

Like a teacher breaking a word problem into steps, the framework could decompose tasks and provide structure that guides the model through complexity.

### Research Inspiration

**Scaffolding in Education**: Temporary support removed as learner gains competence.

> "Scaffolding is the temporary, adjustable support that the MKO provides to learners as they work through new or challenging material within their ZPD. The key aspect of scaffolding is that it is not permanent."
> -- [Vygotsky's ZPD](https://www.simplypsychology.org/zone-of-proximal-development.html)

**AI-Powered Scaffolding Concerns**: Many AI systems use static scaffolding that doesn't fade as users gain proficiency.

> "Many AI systems still rely on static scaffolding, failing to withdraw support gradually as students gain proficiency. This results in over-reliance on AI."
> -- [IJRSI](https://rsisinternational.org/journals/ijrsi/articles/ai-driven-visual-scaffolding-in-education-a-comprehensive-literature-review/)

### Concrete Ideas

#### 3.1 Automatic Task Decomposition

```ruby
Smolagents.agent
  .with_auto_decomposition(
    complexity_threshold: 3,  # Decompose tasks with >3 subgoals
    max_depth: 2              # At most 2 levels of decomposition
  )
```

When the agent receives "Research the environmental impact of Bitcoin mining and propose three solutions", it automatically decomposes:

```
Main Task: Research Bitcoin environmental impact + propose solutions

Subtask 1: Understand Bitcoin mining energy consumption
  - Search for current energy usage data
  - Identify primary energy sources

Subtask 2: Research environmental concerns
  - Carbon emissions
  - Electronic waste
  - Water usage for cooling

Subtask 3: Propose solutions
  - Renewable energy integration
  - Proof-of-stake alternatives
  - Efficiency improvements
```

#### 3.2 Fading Scaffolds

Reduce scaffolding as the model demonstrates competence:

```ruby
class FadingScaffold
  def initialize
    @successful_completions = 0
  end

  def scaffold_level
    case @successful_completions
    when 0..2   then :full      # Complete step-by-step guidance
    when 3..5   then :moderate  # Key checkpoints only
    when 6..10  then :minimal   # Just goal reminders
    else             :none      # Trust the model
    end
  end

  def on_success
    @successful_completions += 1
  end

  def on_failure
    @successful_completions = [@successful_completions - 2, 0].max
  end
end
```

#### 3.3 Thinking Scaffolds

Provide structured thinking templates:

```ruby
PLANNING_SCAFFOLD = <<~SCAFFOLD
  Before taking action, fill out this plan:

  GOAL: [What am I trying to achieve?]

  INFORMATION NEEDED:
  - [What do I need to know?]
  - [What sources might have this?]

  APPROACH:
  1. [First step]
  2. [Second step]
  ...

  POTENTIAL ISSUES:
  - [What could go wrong?]
  - [How would I detect/handle it?]
SCAFFOLD
```

#### 3.4 Progressive Disclosure of Tools

Don't overwhelm with all tools at once:

```ruby
class ProgressiveToolDisclosure
  def tools_for_step(step_number, task_context)
    case step_number
    when 1
      [:search]  # Start with just search
    when 2..3
      [:search, :calculate]  # Add calculation
    else
      all_tools  # Full access after warming up
    end
  end
end
```

---

## 4. Guardrails

### The Vision

What if the system prevented common mistakes before they happen?

Rather than catching errors after the fact, anticipate them and provide guardrails that keep the model on track.

### Research Inspiration

**Feedforward Control**: Anticipate disturbances and act before they affect the system.

> "Feedback control systems are reactive, taking action after changes in the process variable occur. Feedforward control systems are proactive, taking action before changes to the process variable can occur."
> -- [Feedforward Control Wikipedia](https://en.wikipedia.org/wiki/Feed_forward_(control))

**Graceful Degradation in Human Factors**: Design systems that degrade gracefully when errors occur.

> "Research using a human-systems integration approach has developed a framework of graceful degradation with four main elements: a degradation cause, identification of the degradation, prevention of impact on the system, and recovery of nominal operations."
> -- [NASA Technical Reports](https://ntrs.nasa.gov/api/citations/20180006863/downloads/20180006863.pdf)

**Prompt Injection Defense**: Multi-layered defense prevents attacks before they succeed.

> "Effective prompt injection defense requires layered implementation: input validation filters malicious patterns before LLM processing."
> -- [Datadog LLM Guardrails](https://www.datadoghq.com/blog/llm-guardrails-best-practices/)

### Concrete Ideas

#### 4.1 Pre-Execution Validation

```ruby
class ToolCallGuardrail
  PATTERNS = {
    dangerous_query: {
      pattern: /delete|drop|truncate|rm -rf/i,
      action: :block,
      message: "This query appears to be destructive. Please confirm intent."
    },
    overly_broad_search: {
      pattern: /^.{1,5}$/,  # Very short queries
      action: :warn,
      message: "This search is very broad. Consider being more specific."
    },
    potential_infinite_loop: {
      pattern: /search.*search.*search/m,  # Multiple searches in one response
      action: :throttle,
      message: "Multiple searches detected. Pausing to consolidate."
    }
  }

  def validate(tool_call)
    PATTERNS.each do |name, rule|
      if tool_call.to_s.match?(rule[:pattern])
        return GuardrailViolation.new(name, rule[:action], rule[:message])
      end
    end
    nil
  end
end
```

#### 4.2 Anticipatory Context Injection

Inject warnings before common pitfall points:

```ruby
class AnticipatoryConcern
  PITFALL_TRIGGERS = {
    date_sensitive: {
      trigger: /latest|recent|current|today/i,
      injection: "NOTE: My knowledge has a cutoff date. For truly current information, search with the current date (#{Date.today})."
    },
    numeric_precision: {
      trigger: /calculate|compute|percentage|ratio/i,
      injection: "NOTE: I should double-check any calculations. Consider using the calculate tool for precision."
    },
    attribution_needed: {
      trigger: /who said|quote|according to/i,
      injection: "NOTE: Quotes and attributions should be verified. Search for the primary source."
    }
  }

  def augment_prompt(prompt)
    injections = PITFALL_TRIGGERS.filter_map do |name, rule|
      rule[:injection] if prompt.match?(rule[:trigger])
    end

    return prompt if injections.empty?

    "#{prompt}\n\n---\n#{injections.join("\n")}"
  end
end
```

#### 4.3 Output Sanity Checking

Before finalizing, validate the response makes sense:

```ruby
class OutputSanityChecker
  CHECKS = [
    ->(output) { output.length < 10 ? "Response suspiciously short" : nil },
    ->(output) { output.scan(/\?\?\?/).any? ? "Contains placeholder markers" : nil },
    ->(output) { contradictory_statements?(output) ? "May contain contradictions" : nil },
    ->(output) { claims_without_evidence?(output) ? "Contains unsupported claims" : nil }
  ]

  def check(output)
    CHECKS.filter_map { |check| check.call(output) }
  end
end
```

#### 4.4 Conversation Drift Detection

Detect when the agent is going off-track:

```ruby
class DriftDetector
  def initialize(original_task)
    @original_task = original_task
    @task_embedding = embed(original_task)
    @drift_threshold = 0.3
  end

  def check_drift(current_action)
    action_embedding = embed(current_action)
    similarity = cosine_similarity(@task_embedding, action_embedding)

    if similarity < @drift_threshold
      DriftWarning.new(
        "Current action seems unrelated to original task",
        similarity: similarity,
        suggestion: "Consider how this relates to: #{@original_task}"
      )
    end
  end
end
```

---

## 5. Feedback Loops

### The Vision

What if the system learned what works for this specific model?

Over time, the framework should build a model of each model's strengths, weaknesses, and preferences.

### Research Inspiration

**Dynamic Difficulty Adjustment in Games**: Continuously monitor performance and adjust in real-time.

> "At its foundation, DDA relies on continuous monitoring of player performance metrics, such as success rates, reaction times, and decision-making patterns. This data is then processed through sophisticated algorithms that determine the player's skill level and adjust the game's difficulty to match."
> -- [Acer Blog](https://blog.acer.com/en/discussion/1594/dynamic-difficulty-exploring-adaptive-ai-in-video-games)

**Left 4 Dead's AI Director**: Dynamically adjusts based on player stress and performance.

> "The AI Director monitors player performance and stress levels, modifying enemy spawns, item placements, and the overall pacing of the game in real-time. This adaptive system ensures that no two playthroughs are identical."
> -- [Acer Blog](https://blog.acer.com/en/discussion/1594/dynamic-difficulty-exploring-adaptive-ai-in-video-games)

**Adaptive Intelligent Tutoring**: Personalization based on learner performance.

> "An ITS that tailors instructional content based on individual student needs, prior knowledge, and learning styles tends to produce better learning outcomes."
> -- [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12078640/)

### Concrete Ideas

#### 5.1 Model Performance Tracking

```ruby
class ModelPerformanceTracker
  def initialize(model_id)
    @model_id = model_id
    @metrics = ModelMetrics.new
  end

  def record(event)
    case event.type
    when :tool_call_success
      @metrics.tool_success_rate += 1
      @metrics.successful_patterns << event.pattern
    when :tool_call_failure
      @metrics.tool_failure_rate += 1
      @metrics.failure_patterns << event.pattern
    when :self_correction
      @metrics.self_correction_count += 1
    when :required_intervention
      @metrics.intervention_count += 1
    end
  end

  def optimal_temperature
    # Higher temp if model is stuck in patterns, lower if erratic
    base = 0.7
    if @metrics.repetition_rate > 0.3
      base + 0.2  # More creativity needed
    elsif @metrics.error_rate > 0.3
      base - 0.2  # More focus needed
    else
      base
    end
  end
end
```

#### 5.2 Prompt A/B Testing

```ruby
class PromptExperiment
  def initialize(variants)
    @variants = variants  # { name: prompt_template }
    @results = Hash.new { |h, k| h[k] = [] }
  end

  def select_variant
    if @results.values.all? { |r| r.length >= 10 }
      # Enough data, exploit best
      best_variant
    else
      # Still exploring
      @variants.keys.sample
    end
  end

  def record_result(variant, success:, latency:, quality_score:)
    @results[variant] << { success:, latency:, quality_score: }
  end

  def best_variant
    @results.max_by { |_, results| average_quality(results) }.first
  end
end
```

#### 5.3 Adaptive Retry Strategies

```ruby
class AdaptiveRetryStrategy
  def retry_config_for(model, error_type)
    history = error_history(model, error_type)

    {
      max_retries: effective_retry_count(history),
      backoff: effective_backoff(history),
      prompt_modification: effective_modification(history)
    }
  end

  def effective_retry_count(history)
    # If retries rarely help, don't waste tokens
    success_on_retry_rate = history.count(&:succeeded_on_retry) / history.length.to_f
    success_on_retry_rate > 0.5 ? 3 : 1
  end
end
```

#### 5.4 Session-Level Learning

```ruby
class SessionLearner
  def initialize
    @successful_patterns = []
    @failed_patterns = []
  end

  def on_step_complete(step)
    if step.successful?
      @successful_patterns << extract_pattern(step)
    else
      @failed_patterns << extract_pattern(step)
    end
  end

  def augment_next_prompt(prompt)
    if @successful_patterns.any?
      prompt + "\n\nPatterns that have worked well this session:\n" +
        @successful_patterns.last(3).join("\n")
    else
      prompt
    end
  end
end
```

---

## 6. Metacognition

### The Vision

What if we helped models "think about thinking"?

Metacognition--the awareness and regulation of one's own thinking--is key to effective problem-solving. We can scaffold metacognitive processes in models.

### Research Inspiration

**Chain of Thought as Metacognition**: Making reasoning transparent enables self-monitoring.

> "Chain of Thought (CoT) enables AI systems to break down their reasoning into intermediate steps before arriving at a final answer. In AI agent self-evaluation, CoT serves as a mechanism for tracking, analyzing, and evaluating decision-making processes."
> -- [Galileo AI](https://galileo.ai/blog/self-evaluation-ai-agents-performance-reasoning-reflection)

**Self-Reflection in LLMs**: Self-reflection can significantly improve performance.

> "GPT-4 achieved baseline accuracy of 78.6%, improving to 97.1% with unredacted reflection (+18.5 percentage points)."
> -- [Nature](https://www.nature.com/articles/s44387-025-00045-3)

**Dual-Process Theory (Fast and Slow)**: Combining fast intuition with slow deliberation.

> "Inspired by the 'thinking fast and slow' cognitive theory, the SOFAI multi-agent cognitive architecture is based on 'fast'/'slow' solvers and a metacognitive module."
> -- [Nature](https://www.nature.com/articles/s44387-025-00027-5)

**Limitations**: Self-correction has limits without external verification.

> "According to ICLR 2024 findings, large language models cannot self-correct reasoning intrinsically without external verification signals."
> -- [arXiv](https://arxiv.org/pdf/2405.06682)

### Concrete Ideas

#### 6.1 Thinking Out Loud Protocol

Force explicit metacognition:

```ruby
METACOGNITIVE_PROMPT = <<~PROMPT
  Before answering, work through these metacognitive checks:

  UNDERSTANDING CHECK:
  - In my own words, the task is: [restate]
  - The key constraints are: [list]
  - I know I'm done when: [criteria]

  KNOWLEDGE CHECK:
  - I'm confident about: [list]
  - I'm uncertain about: [list]
  - I need to look up: [list]

  STRATEGY CHECK:
  - My approach will be: [describe]
  - Alternative approaches: [list]
  - Why my approach is best: [reason]

  MONITORING PLAN:
  - I'll know I'm on track if: [signals]
  - I'll know I'm off track if: [signals]
  - My checkpoint is at: [when]
PROMPT
```

#### 6.2 Confidence Calibration

Ask the model to rate its confidence and track calibration:

```ruby
class ConfidenceTracker
  def wrap_response(response)
    <<~WRAPPED
      #{response}

      CONFIDENCE ASSESSMENT:
      - Overall confidence (1-5): [rate]
      - Least certain about: [identify]
      - Would benefit from verification: [list]
    WRAPPED
  end

  def calibration_score(predictions_with_confidence)
    # Compare stated confidence to actual accuracy
    # Well-calibrated: 80% confidence = 80% accuracy
    predictions_with_confidence.group_by(&:confidence).map do |confidence, preds|
      actual_accuracy = preds.count(&:correct) / preds.length.to_f
      (confidence - actual_accuracy).abs
    end.sum / 5.0  # Average miscalibration
  end
end
```

#### 6.3 Reflection Points

Insert mandatory reflection at intervals:

```ruby
class ReflectionInjector
  def inject_after_steps(n)
    ->(step_number, context) {
      return nil unless step_number % n == 0

      <<~REFLECTION
        REFLECTION POINT (Step #{step_number}):

        Progress so far:
        - What I've accomplished: [summarize]
        - Original goal: #{context.original_task}
        - Am I on track? [yes/no + why]

        If off track:
        - What went wrong: [analyze]
        - How to correct: [plan]

        Next steps:
        - Immediate: [action]
        - Then: [action]
      REFLECTION
    }
  end
end
```

#### 6.4 External Verification Bridge

Since self-correction has limits, bridge to external verification:

```ruby
class VerificationBridge
  def verify(claim)
    # Use a separate, isolated model call for verification
    verification_response = verification_model.generate(
      "Verify this claim. Respond ONLY with 'VERIFIED', 'REFUTED', or 'UNCERTAIN': #{claim}"
    )

    case verification_response
    when /VERIFIED/i then VerificationResult.verified(claim)
    when /REFUTED/i then VerificationResult.refuted(claim, find_correct_info(claim))
    else VerificationResult.uncertain(claim, suggest_verification_method(claim))
    end
  end
end
```

#### 6.5 Thinking Fast and Slow Architecture

```ruby
Smolagents.agent
  .model(:fast) { quick_model }      # System 1: Fast, intuitive
  .model(:slow) { reasoning_model }  # System 2: Slow, deliberative
  .with_dual_process(
    fast_first: true,                # Try fast approach first
    escalate_on: [:uncertainty, :complexity, :error],
    slow_verifies_fast: true         # Slow model checks fast answers
  )
  .build
```

---

## 7. Progressive Complexity

### The Vision

What if tools had "easy mode" and "expert mode"?

Like video games with difficulty settings, or professional software with basic/advanced views, tools should adapt to context and capability.

### Research Inspiration

**Progressive Disclosure in UX**: Show essential features first, advanced features on demand.

> "Progressive disclosure's goal is to improve usability for novice and experienced users."
> -- [Interaction Design Foundation](https://www.interaction-design.org/literature/topics/progressive-disclosure)

**Flow State in Games**: The balance between challenge and skill.

> "Flow comes from the balance between the level of skill and the size of the challenge at hand."
> -- [Game Design Toolkit](https://tkdev.dss.cloud/gamedesign/toolkit/flow-theory/)

**Desirable Difficulty**: Appropriately challenging tasks lead to better learning.

> "A desirable difficulty is a learning task that requires a considerable but desirable amount of effort, thereby improving long-term performance."
> -- [Wikipedia](https://en.wikipedia.org/wiki/Desirable_difficulty)

### Concrete Ideas

#### 7.1 Tool Complexity Modes

```ruby
class SearchTool
  def self.basic
    new(
      parameters: [:query],
      description: "Search the web",
      examples: ["search(query: 'Ruby programming')"]
    )
  end

  def self.advanced
    new(
      parameters: [:query, :site, :date_range, :type, :language],
      description: "Search with filters for precise results",
      examples: [
        "search(query: 'Ruby 3.2', site: 'ruby-lang.org', date_range: '2024')"
      ],
      tips: [
        "Use site: to restrict to specific domains",
        "Use date_range: for time-sensitive queries"
      ]
    )
  end

  def self.expert
    new(
      parameters: [:query, :site, :date_range, :type, :language, :exclude, :exact_match, :boolean_operators],
      description: "Full search syntax with boolean logic",
      documentation: FULL_SEARCH_DOCUMENTATION
    )
  end
end
```

#### 7.2 Automatic Mode Selection

```ruby
class ToolModeSelector
  def select_mode(model_capability, task_complexity, error_history)
    base_mode = capability_to_mode(model_capability)

    # Upgrade if task demands it
    if task_complexity > base_mode.complexity_ceiling
      base_mode.upgrade
    # Downgrade if errors suggest overwhelm
    elsif recent_errors_suggest_simplification?(error_history)
      base_mode.downgrade
    else
      base_mode
    end
  end
end
```

#### 7.3 Flow State Maintenance

```ruby
class FlowMaintainer
  # Csikszentmihalyi's flow: challenge slightly exceeds skill

  def adjust_challenge(current_skill, recent_performance)
    if bored?(recent_performance)  # Too easy
      increase_challenge(current_skill)
    elsif frustrated?(recent_performance)  # Too hard
      decrease_challenge(current_skill)
    else
      maintain  # In flow
    end
  end

  def bored?(performance)
    performance.success_rate > 0.95 && performance.engagement_signals.low?
  end

  def frustrated?(performance)
    performance.error_rate > 0.4 || performance.repeated_attempts > 3
  end
end
```

#### 7.4 Graduated Autonomy

```ruby
Smolagents.agent
  .with_graduated_autonomy(
    level_1: {
      # Training wheels: confirm every action
      confirm_before: :all_actions,
      suggestions: true,
      guardrails: :strict
    },
    level_2: {
      # Supervised: confirm risky actions only
      confirm_before: [:destructive, :external],
      suggestions: :on_request,
      guardrails: :moderate
    },
    level_3: {
      # Autonomous: full trust
      confirm_before: :nothing,
      suggestions: :none,
      guardrails: :minimal
    }
  )
  .start_at_level(1)
  .promote_on(success_streak: 5)
  .demote_on(critical_error: true)
```

#### 7.5 Skill Tree for Tools

```ruby
TOOL_SKILL_TREE = {
  search: {
    basic: { unlocked: true },
    filtered: { requires: [:basic], unlocks_at: 3.successful_uses },
    boolean: { requires: [:filtered], unlocks_at: 5.successful_uses }
  },
  code_execution: {
    read_only: { unlocked: true },
    simple_scripts: { requires: [:read_only], unlocks_at: 3.successful_uses },
    file_modification: { requires: [:simple_scripts], unlocks_at: 10.successful_uses }
  }
}
```

---

## 8. Collaborative Problem Solving

### The Vision

What if the framework was a partner, not just a runtime?

Instead of the framework being a passive executor, it actively participates in problem-solving: asking clarifying questions, suggesting approaches, catching issues early.

### Research Inspiration

**Rubber Duck Debugging**: Explaining problems leads to solutions.

> "Rubber duck debugging is a debugging technique in software engineering, wherein a programmer explains their code, step by step, in natural language--either aloud or in writing--to reveal mistakes and misunderstandings."
> -- [Wikipedia](https://en.wikipedia.org/wiki/Rubber_duck_debugging)

**AI as Rubber Duck That Talks Back**: AI can be an active thinking partner.

> "The traditional method is powerful, but the duck has one major limitation: it doesn't talk back. What if your 'rubber duck' could not only listen, but also understand, ask clarifying questions, and offer suggestions?"
> -- [GPAI Blog](https://blog.gpai.app/solver/rubber-duck-debugging-ai-pair-programmer)

**Conversational Repair**: Detecting and recovering from communication breakdowns.

> "Conversational repair is the process people use to detect and resolve problems of speaking, hearing, and understanding."
> -- [ACM](https://dl.acm.org/doi/fullHtml/10.1145/3640794.3665558)

**Pair Programming**: Two minds approaching a problem together.

> "Rubber Duck Debugging can be used in pair programming. It allows pairs of developers to explain their code to each other."
> -- [MTU Computing Blog](https://blogs.mtu.edu/computing/2024/08/21/talk-to-the-duck-the-rubber-duck-debugging-method/)

### Concrete Ideas

#### 8.1 Active Task Clarification

```ruby
class TaskClarifier
  def clarify(task)
    ambiguities = detect_ambiguities(task)
    return task if ambiguities.empty?

    ClarificationRequest.new(
      original_task: task,
      questions: ambiguities.map { |a| question_for(a) },
      suggestions: ambiguities.map { |a| suggested_interpretation(a) }
    )
  end

  def detect_ambiguities(task)
    [
      (:time_scope if task !~ /\d{4}|today|recent|current/),
      (:audience if task !~ /for|aimed at|targeting/),
      (:format if task !~ /list|summary|detailed|brief/),
      (:quantity if task =~ /some|a few|several/ && task !~ /\d+/)
    ].compact
  end
end
```

The framework might respond:

```
Before I proceed, let me clarify a few things:

1. TIME SCOPE: You asked for "recent developments." Should I focus on:
   - Last week
   - Last month
   - Last year

2. FORMAT: Would you prefer:
   - A brief summary (2-3 paragraphs)
   - A detailed analysis
   - A bullet-point list

I'll assume "last month" and "bullet-point list" unless you specify otherwise.
```

#### 8.2 Rubber Duck Protocol

```ruby
class RubberDuckProtocol
  def engage(problem)
    <<~DUCK
      Let me help you think through this. Tell me:

      1. WHAT you're trying to do (in plain language)
      2. WHAT you've tried so far
      3. WHERE you're stuck
      4. WHAT you expect to happen vs. what actually happens

      I'll ask clarifying questions as we go.
    DUCK
  end

  def socratic_response(statement)
    # Instead of giving answers, ask questions that lead to insight
    [
      "What makes you think that approach would work?",
      "What assumptions are you making here?",
      "What would happen if that assumption were wrong?",
      "Can you think of a simpler version of this problem?",
      "What's the smallest test case that would reveal the issue?"
    ].sample
  end
end
```

#### 8.3 Collaborative Planning

```ruby
class CollaborativePlanner
  def plan_together(task)
    initial_plan = model.generate_plan(task)

    # Framework reviews and comments
    review = review_plan(initial_plan)

    if review.concerns.any?
      ClarificationStep.new(
        plan: initial_plan,
        framework_feedback: <<~FEEDBACK
          I see your plan. A few observations:

          #{review.concerns.map { |c| "- #{c}" }.join("\n")}

          Questions:
          #{review.questions.map { |q| "- #{q}" }.join("\n")}

          Would you like to adjust the plan, or should we proceed?
        FEEDBACK
      )
    else
      ApprovedPlan.new(initial_plan)
    end
  end
end
```

#### 8.4 Conversation Repair

When misunderstanding occurs, actively repair:

```ruby
class ConversationRepairer
  REPAIR_STRATEGIES = [
    :request_clarification,   # "Could you rephrase that?"
    :offer_interpretation,    # "Did you mean X or Y?"
    :acknowledge_limitation,  # "I don't understand X, but I can help with Y"
    :decompose_request,       # "Let me break this down..."
    :suggest_alternative      # "I can't do X, but I could do Y instead"
  ]

  def repair(misunderstanding)
    strategy = select_strategy(misunderstanding)
    apply_strategy(strategy, misunderstanding)
  end
end
```

#### 8.5 Shared Mental Model

```ruby
class SharedMentalModel
  def initialize
    @understanding = {}
    @assumptions = []
    @agreements = []
  end

  def update_from_turn(turn)
    # Track what's been established
    @understanding.merge!(extract_facts(turn))
    @assumptions += extract_assumptions(turn)
    @agreements += extract_agreements(turn)
  end

  def summarize_shared_understanding
    <<~SUMMARY
      WHAT WE'VE ESTABLISHED:
      #{@understanding.map { |k, v| "- #{k}: #{v}" }.join("\n")}

      CURRENT ASSUMPTIONS:
      #{@assumptions.map { |a| "- #{a}" }.join("\n")}

      AGREED APPROACH:
      #{@agreements.map { |a| "- #{a}" }.join("\n")}
    SUMMARY
  end
end
```

---

## 9. Wild Ideas

### The Really Out There Concepts

These ideas push the boundaries of what an agent framework could be.

#### 9.1 Emotional State Modeling

What if the framework tracked model "emotional state"?

```ruby
class ModelEmotionalState
  # Not anthropomorphizing--tracking computational analogs

  def state
    {
      confidence: recent_success_rate,
      engagement: response_length_trend,
      frustration: retry_rate * error_rate,
      flow: challenge_skill_balance
    }
  end

  def intervention_needed?
    frustration > 0.7 || engagement < 0.3
  end

  def intervention
    case
    when frustration > 0.7
      SimplificationIntervention.new  # Make things easier
    when engagement < 0.3
      ChallengeIntervention.new       # Make things harder
    end
  end
end
```

#### 9.2 Dream Mode

Periodic "dreaming" to consolidate learning:

```ruby
class DreamMode
  # Between sessions, replay and consolidate

  def dream(session_history)
    successful_patterns = extract_successes(session_history)
    failure_patterns = extract_failures(session_history)

    # Generate synthetic scenarios to practice
    practice_scenarios = generate_practice(failure_patterns)

    # Update model understanding through rehearsal
    practice_scenarios.each do |scenario|
      run_internally(scenario)
    end
  end
end
```

#### 9.3 Personality Persistence

Models develop consistent "personality" over time:

```ruby
class ModelPersonality
  # Emergent characteristics from interaction history

  TRAITS = [
    :verbosity,           # Brief vs. detailed
    :caution,             # Risk-taking vs. conservative
    :creativity,          # Novel solutions vs. standard approaches
    :self_confidence,     # Certainty expression
    :collaboration_style  # Asks questions vs. makes assumptions
  ]

  def evolve(session_feedback)
    # Traits shift based on what works
    if session_feedback.preferred_brief_responses?
      @verbosity -= 0.1
    end

    if session_feedback.rewarded_creativity?
      @creativity += 0.1
    end
  end
end
```

#### 9.4 Adversarial Self-Dialogue

The model argues with itself:

```ruby
class AdversarialDialogue
  def challenge(claim)
    advocate_response = model.generate(
      "Argue IN FAVOR of: #{claim}"
    )

    critic_response = model.generate(
      "Argue AGAINST: #{claim}\n\nThe advocate says: #{advocate_response}"
    )

    synthesis = model.generate(
      "Synthesize these perspectives:\n" +
      "FOR: #{advocate_response}\n" +
      "AGAINST: #{critic_response}\n" +
      "What's the most defensible conclusion?"
    )

    synthesis
  end
end
```

#### 9.5 Time-Traveling Debug

Replay past decisions with hindsight:

```ruby
class TimeTraveingDebug
  def analyze_past_decision(decision_point, outcome)
    <<~ANALYSIS
      AT THIS DECISION POINT, you chose: #{decision_point.choice}
      THE OUTCOME WAS: #{outcome}

      IN HINDSIGHT:
      - What information did you have? #{decision_point.available_info}
      - What information were you missing? #{decision_point.missing_info}
      - What would have been a better choice? #{alternative_analysis}

      LESSON LEARNED: #{extract_lesson}
    ANALYSIS
  end
end
```

#### 9.6 Collective Intelligence

Multiple model instances vote on decisions:

```ruby
class CollectiveDecision
  def decide(options, context)
    votes = 3.times.map do |i|
      model.generate(
        "Context: #{context}\n" +
        "Options: #{options.join(', ')}\n" +
        "As evaluator #{i + 1}, which option is best and why?"
      )
    end

    # Find consensus
    chosen = votes.map { |v| extract_choice(v) }.tally.max_by(&:last).first

    CollectiveDecision.new(
      choice: chosen,
      consensus_level: votes.count { |v| extract_choice(v) == chosen } / 3.0,
      reasoning: synthesize_reasoning(votes)
    )
  end
end
```

#### 9.7 Biological Rhythms

Model performance varies--account for it:

```ruby
class PerformanceRhythm
  # API performance varies by time, load, etc.

  def optimal_operation_time?
    # Track when model performs best
    historical_quality_by_hour.max_by(&:last).first == Time.now.hour
  end

  def current_performance_modifier
    hour_quality = historical_quality_by_hour[Time.now.hour]
    best_quality = historical_quality_by_hour.values.max
    hour_quality / best_quality
  end

  def adjust_expectations
    if current_performance_modifier < 0.8
      ReducedExpectations.new(
        message: "API performance typically lower at this time",
        adjustments: { timeout: +30.percent, retries: +1 }
      )
    end
  end
end
```

#### 9.8 Forgetting as Feature

Intentional forgetting to prevent fixation:

```ruby
class IntentionalForgetting
  def should_forget?(memory)
    [
      memory.led_to_failure?,
      memory.confidence_was_miscalibrated?,
      memory.created_unhelpful_fixation?
    ].any?
  end

  def selective_amnesia(memories)
    memories.reject { |m| should_forget?(m) }
  end
end
```

#### 9.9 Narrative Arc

Tasks have dramatic structure:

```ruby
class NarrativeArc
  BEATS = [
    :exposition,        # Understanding the task
    :rising_action,     # Building toward solution
    :complication,      # Unexpected challenges
    :climax,            # Key breakthrough
    :falling_action,    # Verification and cleanup
    :resolution         # Final answer
  ]

  def current_beat(task_progress)
    # Provide narrative framing
    "You are in the #{beat_name} phase. " +
    BEAT_GUIDANCE[current_beat]
  end
end
```

---

## Implementation Priority

Based on potential impact and implementation complexity:

### High Impact, Lower Complexity
1. **Example Injection** - Error-triggered examples (Section 2)
2. **Anticipatory Guardrails** - Pre-pitfall warnings (Section 4.2)
3. **Metacognitive Prompts** - Thinking out loud protocol (Section 6.1)
4. **Task Clarification** - Active clarification (Section 8.1)

### High Impact, Higher Complexity
5. **Capability Probing** - Model fingerprinting (Section 1)
6. **Fading Scaffolds** - Adaptive support (Section 3.2)
7. **Session Learning** - Real-time adaptation (Section 5.4)
8. **Dual Process Architecture** - Fast/slow thinking (Section 6.5)

### Experimental (Worth Exploring)
9. **Flow Maintenance** - Challenge/skill balance (Section 7.3)
10. **Graduated Autonomy** - Progressive trust (Section 7.4)
11. **Adversarial Self-Dialogue** - Self-challenging (Section 9.4)
12. **Collective Intelligence** - Multi-instance voting (Section 9.6)

---

## Sources

### Educational Psychology & Learning Theory
- [Simply Psychology - Zone of Proximal Development](https://www.simplypsychology.org/zone-of-proximal-development.html)
- [Wikipedia - Worked-example effect](https://en.wikipedia.org/wiki/Worked-example_effect)
- [AFT - Cognitive Apprenticeship](https://www.aft.org/ae/winter1991/collins_brown_holum)
- [Wikipedia - Desirable difficulty](https://en.wikipedia.org/wiki/Desirable_difficulty)
- [PMC - AI-driven ITS in K-12 Education](https://pmc.ncbi.nlm.nih.gov/articles/PMC12078640/)
- [arXiv - Theory of Adaptive Scaffolding for LLM-Based Pedagogical Agents](https://arxiv.org/html/2508.01503v1)
- [IJRSI - AI-Driven Visual Scaffolding in Education](https://rsisinternational.org/journals/ijrsi/articles/ai-driven-visual-scaffolding-in-education-a-comprehensive-literature-review/)

### Game Design & Dynamic Difficulty
- [Acer Blog - Dynamic Difficulty in Video Games](https://blog.acer.com/en/discussion/1594/dynamic-difficulty-exploring-adaptive-ai-in-video-games)
- [Wikipedia - Dynamic game difficulty balancing](https://en.wikipedia.org/wiki/Dynamic_game_difficulty_balancing)
- [Game Design Toolkit - Flow Theory](https://tkdev.dss.cloud/gamedesign/toolkit/flow-theory/)
- [Medium - Flow State in Game Design](https://medium.com/@aniketisg/the-influence-of-flow-state-in-game-design-2b26a0408da0)

### AI Agents & LLM Research
- [Galileo AI - Self-Evaluation in AI Agents with Chain of Thought](https://galileo.ai/blog/self-evaluation-ai-agents-performance-reasoning-reflection)
- [Nature - Self-reflection enhances LLMs](https://www.nature.com/articles/s44387-025-00045-3)
- [Nature - Fast, slow, and metacognitive thinking in AI](https://www.nature.com/articles/s44387-025-00027-5)
- [arXiv - Self-Reflection in LLM Agents](https://arxiv.org/pdf/2405.06682)
- [arXiv - Agentic RAG Survey](https://arxiv.org/abs/2501.09136)
- [arXiv - Memory in the Age of AI Agents](https://arxiv.org/abs/2512.13564)

### Human-Computer Interaction
- [Interaction Design Foundation - Progressive Disclosure](https://www.interaction-design.org/literature/topics/progressive-disclosure)
- [NN/g - Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
- [Wikipedia - Rubber duck debugging](https://en.wikipedia.org/wiki/Rubber_duck_debugging)
- [ACM - Conversational Repair](https://dl.acm.org/doi/fullHtml/10.1145/3640794.3665558)
- [GPAI Blog - Rubber Duck Debugging with AI](https://blog.gpai.app/solver/rubber-duck-debugging-ai-pair-programmer)

### Control Systems & Engineering
- [Wikipedia - Feedforward Control](https://en.wikipedia.org/wiki/Feed_forward_(control))
- [NASA - Graceful Degradation](https://ntrs.nasa.gov/api/citations/20180006863/downloads/20180006863.pdf)
- [arXiv - Intelligent Execution through Plan Analysis](https://arxiv.org/html/2403.12162)

### Security & Guardrails
- [Datadog - LLM Guardrails Best Practices](https://www.datadoghq.com/blog/llm-guardrails-best-practices/)
- [OWASP - LLM Prompt Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html)

---

*Generated: January 2026*
*For: smolagents-ruby novel interaction pattern ideation*
