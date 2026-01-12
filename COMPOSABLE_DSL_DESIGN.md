# Composable DSL Design

## Vision

A unified, chainable DSL for composing agents, tools, and pipelines in smolagents-ruby.

```ruby
# === AGENT COMPOSITION ===
agent = Smolagents.agent(:code)
  .model { OpenAIModel.lm_studio("llama3") }
  .tools(:google_search, :visit_webpage, :wikipedia)
  .planning(interval: 3)
  .max_steps(10)
  .on(:step_complete) { |step| logger.info(step) }
  .build

# === TOOL PIPELINE COMPOSITION ===
research = Smolagents.pipeline
  .call(:google_search, query: :input)
  .then(:visit_webpage) { |prev| { url: prev.first[:url] } }
  .select { |r| r[:content].length > 100 }
  .call(:summarize, text: :prev)

# Pipeline becomes a tool
agent = Smolagents.agent(:tool_calling)
  .tools(research.as_tool("research", "Deep research on a topic"))
  .build

# === INLINE TOOL EXPRESSIONS ===
result = Smolagents.run(:google_search, query: "Ruby 4.0")
  .then(:visit_webpage) { |r| { url: r.first[:url] } }
  .result

# === COMPOSE AGENTS TOO ===
researcher = Smolagents.agent(:code).tools(:search, :visit).build
writer = Smolagents.agent(:code).tools(:write_file).build

team = Smolagents.team
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .coordinate { "Research then write a report" }
  .build
```

---

## Components

| Component | Purpose | Returns |
|-----------|---------|---------|
| `Smolagents.agent(type)` | Start agent builder | `AgentBuilder` |
| `Smolagents.pipeline` | Start pipeline builder | `Pipeline` |
| `Smolagents.run(tool, **args)` | Execute tool, return chainable | `PipelineExecution` |
| `Smolagents.team` | Start team builder | `TeamBuilder` |

---

## What We Have

### Existing Infrastructure

| Component | Location | What It Does |
|-----------|----------|--------------|
| `ToolResult` | `tools/result.rb` | Chainable, Enumerable results with `select`, `map`, `take`, etc. |
| `Tools.define_tool` | `tools/tool_dsl.rb` | Dynamic tool creation from blocks |
| `Tool` base class | `tools/tool.rb` | Class-level attributes, `call`, `execute` |
| `Tools::Registry` | `tools/registry.rb` | Tool lookup by name |
| `Callbackable` | `concerns/callbackable.rb` | `register_callback`, chainable |
| `Planning` | `concerns/planning.rb` | Planning interval, templates |
| `ManagedAgents` | `concerns/managed_agents.rb` | Sub-agent orchestration |
| `Agent.code` / `.tool_calling` | `agents/agent.rb` | Factory methods |
| `OpenAIModel.lm_studio` etc. | `models/openai_model.rb` | Model factory methods |
| `Smolagents.configure` | `config/configuration.rb` | Block-based global config |

### Patterns Already Established

```ruby
# Chainable results (ToolResult)
result.select { }.sort_by { }.take(5).pluck(:field)

# Block configuration
Smolagents.configure { |c| c.max_steps = 10 }

# Factory methods
Agent.code(model:, tools:)
OpenAIModel.lm_studio("model-id")

# Dynamic tool creation
Tools.define_tool("name", description: "...", inputs: {}, output_type: "string") { |x| }

# Callback registration (chainable)
agent.register_callback(:on_step) { }.register_callback(:on_error) { }
```

---

## Implementation Plan

### Phase 1: Pipeline (Foundation)

**New files:**
- `lib/smolagents/pipeline.rb`
- `lib/smolagents/pipeline/step.rb`
- `spec/smolagents/pipeline_spec.rb`

**Pipeline** - Chainable tool composition

```ruby
Pipeline = Data.define(:steps, :registry) do
  def self.new(registry: Tools::Registry)
    super(steps: [], registry:)
  end

  # Add a tool call step
  def call(tool_name, **static_args, &dynamic_args)
    with(steps: steps + [Step::Call.new(tool_name, static_args, dynamic_args)])
  end
  alias_method :then, :call

  # Add a transform step (operates on ToolResult)
  def transform(&block)
    with(steps: steps + [Step::Transform.new(block)])
  end

  # ToolResult-style transforms (delegate to transform)
  %i[select reject map flat_map sort_by take drop compact uniq].each do |method|
    define_method(method) do |*args, &block|
      transform { |result| result.public_send(method, *args, &block) }
    end
  end

  # Execute the pipeline
  def run(**input)
    steps.reduce(ToolResult.new(input, tool_name: "input")) do |prev, step|
      step.execute(prev, registry:)
    end
  end
  alias_method :result, :run

  # Convert to a Tool
  def as_tool(name, description, input_spec = nil)
    pipeline = self
    Tools.define_tool(
      name,
      description:,
      inputs: input_spec || infer_inputs,
      output_type: "any"
    ) { |**kwargs| pipeline.run(**kwargs).data }
  end
end
```

**Step types:**

```ruby
module Pipeline::Step
  Call = Data.define(:tool_name, :static_args, :dynamic_args) do
    def execute(prev, registry:)
      tool = registry.get(tool_name)
      args = resolve_args(prev)
      tool.call(**args)
    end

    private

    def resolve_args(prev)
      args = static_args.transform_values { |v| resolve_value(v, prev) }
      args.merge!(dynamic_args.call(prev)) if dynamic_args
      args
    end

    def resolve_value(value, prev)
      case value
      when :input then prev.data
      when :prev then prev.data
      when Symbol then prev.dig(value)
      else value
      end
    end
  end

  Transform = Data.define(:block) do
    def execute(prev, registry:)
      block.call(prev)
    end
  end
end
```

**Entry point:**

```ruby
# lib/smolagents.rb
module Smolagents
  def self.pipeline
    Pipeline.new
  end

  def self.run(tool_name, **args)
    Pipeline.new.call(tool_name, **args)
  end
end
```

---

### Phase 2: AgentBuilder

**New files:**
- `lib/smolagents/builders/agent_builder.rb`
- `spec/smolagents/builders/agent_builder_spec.rb`

```ruby
AgentBuilder = Data.define(
  :agent_type, :model_block, :tool_names, :tool_instances,
  :planning_config, :step_config, :callbacks
) do
  def self.new(agent_type)
    super(
      agent_type:,
      model_block: nil,
      tool_names: [],
      tool_instances: [],
      planning_config: {},
      step_config: {},
      callbacks: []
    )
  end

  def model(&block)
    with(model_block: block)
  end

  def tools(*names_or_instances)
    names, instances = names_or_instances.partition { |t| t.is_a?(Symbol) || t.is_a?(String) }
    with(
      tool_names: tool_names + names.map(&:to_sym),
      tool_instances: tool_instances + instances
    )
  end

  def planning(interval: nil, templates: nil)
    with(planning_config: { interval:, templates: }.compact)
  end

  def max_steps(n)
    with(step_config: step_config.merge(max_steps: n))
  end

  def on(event, &block)
    with(callbacks: callbacks + [[event, block]])
  end

  def build
    model = model_block&.call || raise(ArgumentError, "Model required")
    tools = resolve_tools

    agent_class = case agent_type
      when :code then Agents::Code
      when :tool_calling then Agents::ToolCalling
      else raise ArgumentError, "Unknown agent type: #{agent_type}"
    end

    agent = agent_class.new(
      model:,
      tools:,
      **planning_config,
      **step_config
    )

    callbacks.each { |event, block| agent.register_callback(event, &block) }

    agent
  end

  private

  def resolve_tools
    resolved = tool_names.map { |name| Tools::Registry.get(name) }
    resolved + tool_instances
  end
end
```

**Entry point:**

```ruby
module Smolagents
  def self.agent(type)
    AgentBuilder.new(type)
  end
end
```

---

### Phase 3: TeamBuilder

**New files:**
- `lib/smolagents/builders/team_builder.rb`
- `spec/smolagents/builders/team_builder_spec.rb`

```ruby
TeamBuilder = Data.define(:agents, :coordinator_config) do
  def self.new
    super(agents: {}, coordinator_config: {})
  end

  def agent(agent_or_builder, as:)
    resolved = agent_or_builder.is_a?(AgentBuilder) ? agent_or_builder.build : agent_or_builder
    with(agents: agents.merge(as.to_s => resolved))
  end

  def coordinate(instructions = nil, &block)
    with(coordinator_config: { instructions: instructions || block&.call })
  end

  def model(&block)
    with(coordinator_config: coordinator_config.merge(model_block: block))
  end

  def build
    model = coordinator_config[:model_block]&.call || agents.values.first.model

    Agents::Code.new(
      model:,
      tools: [],
      managed_agents: agents,
      custom_instructions: coordinator_config[:instructions]
    )
  end
end
```

**Entry point:**

```ruby
module Smolagents
  def self.team
    TeamBuilder.new
  end
end
```

---

## Migration Path

### Existing Code Still Works

```ruby
# This still works
agent = Agents::Code.new(model:, tools:, max_steps: 10)

# This is the new way
agent = Smolagents.agent(:code)
  .model { my_model }
  .tools(:search, :visit)
  .max_steps(10)
  .build
```

### Incremental Adoption

1. **Phase 1**: Add `Pipeline` - immediately useful standalone
2. **Phase 2**: Add `AgentBuilder` - cleaner agent setup
3. **Phase 3**: Add `TeamBuilder` - multi-agent composition

Each phase is independently valuable and doesn't break existing code.

---

## File Structure

```
lib/smolagents/
├── pipeline.rb                 # Pipeline + Step classes
├── builders/
│   ├── agent_builder.rb        # AgentBuilder
│   └── team_builder.rb         # TeamBuilder
└── smolagents.rb               # Entry points (agent, pipeline, run, team)
```

---

## Ruby 4.0 Features Used

| Feature | Usage |
|---------|-------|
| `Data.define` | Immutable builders (Pipeline, AgentBuilder, TeamBuilder) |
| `Data#with` | Chainable immutable updates |
| Pattern matching | Step execution dispatch |
| Endless methods | Simple delegations |
| Numbered block params | Transform lambdas |

---

## Success Criteria

- [ ] `Smolagents.pipeline.call(:x).then(:y).run` works
- [ ] `pipeline.as_tool("name", "desc")` returns usable Tool
- [ ] `Smolagents.agent(:code).model { }.tools(:x).build` works
- [ ] `Smolagents.team.agent(a, as: "x").agent(b, as: "y").build` works
- [ ] All existing tests still pass
- [ ] New DSL has full test coverage
