# smolagents-ruby Architecture

Delightfully simple agents that think in Ruby.

---

## The Vision

```ruby
# This is what we're building:
agent = Smolagents.code
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .tools(:web_search, :visit_webpage)
  .build

result = agent.run("Find the latest Ruby news")
```

Simple. Obvious. Beautiful.

---

## Four Core Abstractions

```
Agent  →  runs tasks using model + tools
Model  →  talks to LLMs
Tool   →  does one thing well
Result →  immutable, chainable output
```

Everything else serves these four.

---

## Patterns That Spark Joy

### Data.define Everywhere

```ruby
# Immutable, pattern-matchable, self-documenting
ToolCall = Data.define(:id, :name, :arguments)
RunResult = Data.define(:output, :steps, :token_usage)

# With behavior
Outcome = Data.define(:state, :value, :error) do
  def success? = state == :success
  def failed? = !success?
  def then(&) = success? ? yield(value) : self
end
```

### Fluent Builders

```ruby
# Reads like English, validates eagerly, fails helpfully
agent = Smolagents.code
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .tools(:search, :calculator)
  .max_steps(10)
  .build
```

### Chainable Results

```ruby
# Functional, composable, never mutates
result.select { |r| r[:score] > 0.8 }
      .map { |r| r[:title] }
      .take(5)
```

### Pattern Matching

```ruby
# Intent is obvious, exhaustiveness checked
case step
in ActionStep[tool_calls:] then execute(tool_calls)
in FinalAnswerStep[answer:] then return answer
end
```

---

## What We Don't Do

- No `sleep()` - use queues
- No `Timeout.timeout` - use deadlines
- No mutable state - use Data.define
- No backwards compat - delete old code
- No features without tests

---

## The Five DSLs

| DSL | Purpose | Returns |
|-----|---------|---------|
| **AgentBuilder** | Configure agents | Agent |
| **TeamBuilder** | Compose agents | Coordinator Agent |
| **ModelBuilder** | Configure models + reliability | Model |
| **Pipeline** | Chain tool calls | ToolResult |
| **Goal** | Rich task representation | Goal (result) |

All provide: immutability, fluent chaining, freeze!, help, validation, pattern matching.

### Compositional Tower

```
Pipeline (deterministic tool chains)
    ↓ .as_tool()
Tool (reusable computation)
    ↓ AgentBuilder.tools()
AgentBuilder (single agent)
    ↓ TeamBuilder.agent()
TeamBuilder (multi-agent coordination)
    ↓ Goal.with_agent()
Goal (rich task with criteria)
```

---

## Event-Driven Architecture

### The Principle

**No sleeps. No polling. No thread joins.**

When something needs to wait, it blocks on a queue. When something happens, it emits an event. This makes the system deterministic, testable, and fast.

```ruby
# Wrong: polling
loop do
  sleep(0.1)
  check_for_results
end

# Wrong: callbacks with unclear timing
on_complete { |result| ... }  # When does this fire?

# Right: event-driven
event = queue.pop      # Blocks until event arrives
handle(event)          # Process immediately
```

### Why Events, Not Callbacks

| Callbacks | Events |
|-----------|--------|
| Fire immediately, interrupt flow | Queue for controlled processing |
| Implicit ordering | Explicit ordering via queue |
| Hard to test (timing-dependent) | Easy to test (inject events) |
| Can't replay | Can replay, log, persist |

Events are data. Callbacks are behavior. Data is easier to reason about.

### The Minimal Event System (~100 LOC)

Three components. No more.

**1. Event Types** - Immutable Data.define objects

```ruby
# Events are just data
StepCompleted = Data.define(:step, :outcome, :duration)
ToolCallCompleted = Data.define(:tool_name, :result, :duration)
ModelGenerateCompleted = Data.define(:model_id, :tokens, :duration)
ErrorOccurred = Data.define(:error, :recoverable, :context)
```

**2. Emitter** - Push events to queue

```ruby
module Emitter
  def connect_to(queue)
    @event_queue = queue
  end

  def emit(event)
    @event_queue&.push(event)
  end
end
```

**3. Consumer** - Register handlers, dispatch events

```ruby
module Consumer
  def on(event_type, &handler)
    @handlers ||= {}
    @handlers[event_type] = handler
  end

  def consume(event)
    @handlers&.[](event.class)&.call(event)
  end
end
```

**The Queue** - Just use `Thread::Queue`. It's already perfect:
- `push` is non-blocking
- `pop` blocks until event available (no polling!)
- `pop(true)` is non-blocking for draining
- Thread-safe by design

### Event Flow

```
Agent.run(task)
│
├── @queue = Thread::Queue.new
├── connect_to(@queue)
│
├── step(task)
│   ├── model.generate(...)
│   │   └── emit(ModelGenerateCompleted)  →  queue.push
│   │
│   ├── execute_tool(...)
│   │   └── emit(ToolCallCompleted)       →  queue.push
│   │
│   └── emit(StepCompleted)               →  queue.push
│
├── drain_events()
│   └── while event = queue.pop(true) rescue nil
│       └── consume(event)                →  handler.call
│
└── loop until final_answer
```

### What We Deleted

The previous event system had 603 LOC. We deleted:

| Deleted | LOC | Why |
|---------|-----|-----|
| EventQueue class | 219 | Thread::Queue does this |
| Priority levels | ~50 | YAGNI - events process in order |
| Scheduling (due_at) | ~40 | YAGNI - no delayed events needed |
| Stale cleanup | ~30 | YAGNI - queues drain each step |
| Stats/metrics | ~20 | Use telemetry instead |
| Legacy aliases | 105 | Backwards compat we don't need |
| Rate limit helpers | ~30 | Belongs in concerns, not events |

**Result: 603 LOC → ~100 LOC**

### Key Event Types

| Event | When | Data |
|-------|------|------|
| `ModelGenerateCompleted` | After LLM response | model_id, tokens, duration |
| `ToolCallCompleted` | After tool execution | tool_name, result, duration |
| `StepCompleted` | After each agent step | step, outcome, duration |
| `TaskCompleted` | After agent.run() finishes | task, result, total_duration |
| `ErrorOccurred` | On recoverable/fatal errors | error, recoverable, context |

### Usage

```ruby
# Register handlers via builder
agent = Smolagents.code
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .tools(:search)
  .on(StepCompleted) { |e| puts "Step #{e.step.number}: #{e.outcome}" }
  .on(ErrorOccurred) { |e| logger.error(e.error) }
  .build

# Or directly on agent
agent.on(ToolCallCompleted) { |e| track_tool_usage(e) }

# Events fire during run
agent.run("Find Ruby news")
```

### Testing Events

Events are data, so testing is trivial:

```ruby
it "emits StepCompleted after each step" do
  events = []
  agent.on(StepCompleted) { |e| events << e }

  agent.run("test task")

  expect(events.size).to eq(agent.steps.size)
  expect(events.first).to be_a(StepCompleted)
end

it "can inject events for testing" do
  queue = Thread::Queue.new
  queue.push(StepCompleted.new(step: mock_step, outcome: :success, duration: 1.0))

  agent.connect_to(queue)
  # Test handler behavior with controlled events
end
```

---

## Execution Model

The agent execution is built on a Fiber-first architecture where `fiber_loop()` is the single source of truth.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface                           │
├─────────────┬─────────────────────┬─────────────────────────┤
│   run()     │   run_stream()      │   run_fiber()           │
│   (sync)    │   (Enumerator)      │   (bidirectional)       │
├─────────────┴─────────────────────┴─────────────────────────┤
│                   fiber_loop()                               │
│              THE ReAct loop primitive                        │
├─────────────────────────────────────────────────────────────┤
│   Fiber.yield(ActionStep | ControlRequest | RunResult)      │
└─────────────────────────────────────────────────────────────┘
```

### Execution Modes

| Mode | Method | Returns | Control Requests |
|------|--------|---------|------------------|
| Sync | `run()` | `RunResult` | Uses `SyncBehavior` defaults |
| Stream | `run(stream: true)` | `Enumerator<ActionStep>` | Auto-approves |
| Fiber | `run_fiber()` | `Fiber` | Yields to consumer |

### Control Requests

Tools and agents can pause execution to request input:

```ruby
# In a tool
def execute(path:)
  return "Aborted" unless request_confirmation(
    action: "delete", description: "Delete #{path}", reversible: false
  )
  File.delete(path)
end

# Consumer handles the request
fiber = agent.run_fiber(task)
loop do
  case fiber.resume
  in Types::ControlRequests::UserInput => req
    fiber.resume(Types::ControlRequests::Response.respond(request_id: req.id, value: gets.chomp))
  in Types::RunResult => result
    break result
  end
end
```

### Sync Behavior Defaults

| Request Type | Default Behavior |
|--------------|------------------|
| `UserInput` | Use `default_value` or raise |
| `Confirmation` | Auto-approve if reversible |
| `SubAgentQuery` | Skip (return nil) |

---

## Ractor Usage

**Only code execution needs Ractors.**

| Component | Ractor? | Why |
|-----------|---------|-----|
| `Executors::Ractor` | Yes | Sandboxes model-generated Ruby |
| `Executors::Ruby` | No | In-process sandbox alternative |
| Models | No | HTTP calls work fine in threads |
| Tools | No | Called via message passing |

### The Isolation Boundary

```
TRUSTED ZONE (Main Thread)          UNTRUSTED ZONE (Ractor)
─────────────────────────────────────────────────────────
Model HTTP calls                    Agent-generated code
JSON parsing                        Sandbox execution
Agent logic
Tool execution (via messages) ←──── Tool call requests
```

### Data.define and Ractors

Data.define objects ARE shareable when their values are shareable:

```ruby
# Shareable: primitives, frozen strings, symbols
Point = Data.define(:x, :y)
Ractor.shareable?(Point.new(x: 1, y: 2))  # => true

# Not shareable: unfrozen strings, Procs, complex objects
Ractor.shareable?(Point.new(x: "hello", y: -> { }))  # => false
```

---

## Directory Structure

```
lib/smolagents/
├── agents/        # CodeAgent, ToolCallingAgent
├── builders/      # AgentBuilder, ModelBuilder, TeamBuilder
├── concerns/      # Composable modules
├── events/        # Typed events + emitter/consumer
├── executors/     # Ruby, Docker, Ractor sandboxes
├── models/        # OpenAI, Anthropic, LiteLLM
├── persistence/   # Save/load agents
├── telemetry/     # Instrumentation, logging
├── tools/         # Tool base + built-ins
├── types/         # Data.define types
└── pipeline.rb    # Composable tool chains
```
