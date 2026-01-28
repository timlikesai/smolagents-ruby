# Demo Frontend Plan: smolagents-ruby Visual Builder

**For:** Morning stakeholder demo
**Vibe:** Simple, clean, magical
**Infrastructure:** mac-studio, macbook-pro-m4, llama-cpp-ultra

---

## Vision

> "The magic isn't in the framework. The magic is in what the model can do when the framework gets out of its way."

The demo frontend should let stakeholders **see** this magic:
- Watch small models punch above their weight
- See agents think, decide, and collaborate in real-time
- Build agents visually with the beautiful DSL
- Feel the distributed infrastructure working together

---

## Core Experiences

### 1. Agent Playground (Primary Demo)

**What it does:** Interactive agent builder with live execution visualization

```
┌─────────────────────────────────────────────────────────────────────┐
│  smolagents.rb                                    [mac-studio ✓]   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────┐     ┌────────────────────────────────────┐│
│  │ AGENT BUILDER       │     │ LIVE EXECUTION                     ││
│  │                     │     │                                    ││
│  │ Model: [fast_20b ▼] │     │ ▸ Task: "Find Ruby 3.3 features"  ││
│  │ Endpoint: [ultra ▼] │     │                                    ││
│  │                     │     │ Step 1: Thinking...               ││
│  │ Persona:            │     │   └─ "I'll search for Ruby 3.3    ││
│  │ [x] :researcher     │     │      release notes"               ││
│  │ [ ] :coder          │     │                                    ││
│  │ [ ] :analyst        │     │ Step 2: Tool Call                 ││
│  │                     │     │   └─ web_search("Ruby 3.3")       ││
│  │ Tools:              │     │       → 3 results found           ││
│  │ [x] :search         │     │                                    ││
│  │ [x] :calculate      │     │ Step 3: Final Answer              ││
│  │ [ ] :web            │     │   └─ "Ruby 3.3 features..."       ││
│  │                     │     │                                    ││
│  │ Planning: [off ▼]   │     │ ─────────────────────────────────││
│  │ Memory: [50k ▼]     │     │ Tokens: 1,234 | Time: 2.3s       ││
│  │                     │     │ Model: fast_20b on llama-ultra    ││
│  └─────────────────────┘     └────────────────────────────────────┘│
│                                                                     │
│  Task: [Find the latest Ruby release notes                    ] [▶]│
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Magic Moments:**
- Building an agent takes 3 clicks
- Results stream in real-time (SSE)
- Each step unfolds with subtle animation
- Token counter shows efficiency
- Hover over a step to see the raw exchange

### 2. Research Swarm Demo

**What it does:** Showcase multi-agent coordination

```
┌─────────────────────────────────────────────────────────────────────┐
│  Research Swarm                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│            ┌──────────────┐                                        │
│            │  Coordinator │ ← fast_20b on ultra                    │
│            └──────┬───────┘                                        │
│       ╔═══════════╬═══════════╗                                    │
│       ║           ║           ║                                    │
│  ┌────▼────┐ ┌────▼────┐ ┌────▼────┐                              │
│  │ Broad   │ │  Deep   │ │Academic │ ← parallel on mac-studio     │
│  │ ████░░░ │ │ ██████░ │ │ ████░░░ │                              │
│  └─────────┘ └─────────┘ └─────────┘                              │
│       ║           ║           ║                                    │
│       ╚═══════════╬═══════════╝                                    │
│            ┌──────▼───────┐                                        │
│            │  Synthesizer │ ← coder_30b for final output           │
│            └──────────────┘                                        │
│                                                                     │
│  Query: "What's new in AI agent frameworks?"                       │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐│
│  │ Synthesized Result:                                            ││
│  │                                                                ││
│  │ Based on research from 12 sources across web, academic, and   ││
│  │ deep-dive analysis...                                         ││
│  └────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

**Magic Moments:**
- See agents work in parallel (real distributed computation)
- Progress bars for each researcher
- Watch results aggregate in real-time
- Final synthesis shows the power of coordination

### 3. Infrastructure Dashboard

**What it does:** Show the distributed compute at work

```
┌─────────────────────────────────────────────────────────────────────┐
│  Infrastructure                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────┐ ┌───────────────────────┐               │
│  │ llama-cpp-ultra      │ │ mac-studio            │               │
│  │ ✓ HEALTHY  14ms      │ │ ✓ HEALTHY  23ms       │               │
│  │                      │ │                        │               │
│  │ Models:              │ │ Models:               │               │
│  │ • fast_20b    ⚡     │ │ • gpt_20b      ⚡     │               │
│  │ • coder_30b   🧠     │ │ • glm_flash    ⚡     │               │
│  │ • devstral    💻     │ │ • nemotron_30b 🧠     │               │
│  │ • qwen_math   📐     │ │ • medgemma     🏥     │               │
│  │ • lfm_tiny    🪶     │ └────────────────────────┘               │
│  └───────────────────────┘                                         │
│                                                                     │
│  ┌───────────────────────┐                                         │
│  │ macbook-pro-m4       │  Total Active Requests: 3               │
│  │ ✓ HEALTHY  8ms       │  Tokens/min: 12,340                     │
│  │                      │  Avg Latency: 145ms                     │
│  │ Models:              │                                         │
│  │ • glm_flash    ⚡    │                                         │
│  │ • nemotron_nano 🪶   │                                         │
│  └───────────────────────┘                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### 4. Code Preview (The DSL Beauty)

**What it does:** Show the Ruby code that would create the agent

```ruby
# Generated from your configuration

agent = Smolagents.agent
  .model { fast_model }                    # fast_20b on llama-ultra
  .tools(:search, :calculate)              # 2 tools enabled
  .as(:researcher)                         # Research persona
  .max_steps(10)                           # Step limit
  .memory(budget: 50_000)                  # Token budget
  .on(:step_complete) { |e| stream(e) }   # Real-time events
  .build

result = agent.run("Find the latest Ruby release notes")
```

This panel should highlight how **beautiful** the DSL is.

---

## Technical Architecture

### Stack Recommendation

**Sinatra + Hotwire + TailwindCSS**

Why this stack:
- **Sinatra**: Lightweight, Ruby-native, perfect for demo
- **Hotwire (Turbo + Stimulus)**: Real-time updates without SPA complexity
- **TailwindCSS**: Beautiful, fast to style, consistent design
- **SSE (Server-Sent Events)**: Real-time agent execution streaming

Alternative: **Roda** (even lighter) or **Rails** (if we want generators)

### Directory Structure

```
demo/
├── app.rb                    # Sinatra main app
├── config.ru                 # Rack config
├── Gemfile
├── lib/
│   ├── demo_agent.rb         # Agent execution wrapper
│   ├── event_broadcaster.rb  # SSE broadcasting
│   └── infrastructure.rb     # Re-use existing infra
├── views/
│   ├── layout.erb
│   ├── playground.erb        # Agent builder
│   ├── swarm.erb             # Research swarm demo
│   ├── infrastructure.erb    # Health dashboard
│   └── partials/
│       ├── _step.erb         # Step rendering
│       ├── _agent_card.erb   # Agent status card
│       └── _event_stream.erb # Live event stream
├── public/
│   ├── css/
│   │   └── app.css           # Tailwind compiled
│   └── js/
│       ├── controllers/      # Stimulus controllers
│       │   ├── agent_builder_controller.js
│       │   ├── event_stream_controller.js
│       │   └── infrastructure_controller.js
│       └── application.js
└── Procfile                  # For running demo
```

### Key Components

#### 1. Agent Execution with Streaming

```ruby
# lib/demo_agent.rb

class DemoAgent
  include Smolagents::Events::Consumer

  def initialize(config, stream:)
    @stream = stream
    @agent = build_agent(config)
  end

  def run(task)
    # Subscribe to events and forward to SSE
    @agent.on(:step_start) { |e| @stream.send(:step_start, e) }
    @agent.on(:tool_call) { |e| @stream.send(:tool_call, e) }
    @agent.on(:step_complete) { |e| @stream.send(:step_complete, e) }
    @agent.on(:error) { |e| @stream.send(:error, e) }

    result = @agent.run(task)
    @stream.send(:complete, result)
    result
  end

  private

  def build_agent(config)
    builder = Smolagents.agent
                        .model { model_for(config[:model], config[:endpoint]) }

    config[:tools]&.each { |t| builder = builder.tools(t) }
    builder = builder.as(config[:persona]) if config[:persona]
    builder = builder.max_steps(config[:max_steps]) if config[:max_steps]
    builder = builder.planning(interval: config[:planning]) if config[:planning]

    builder.build
  end

  def model_for(model_id, endpoint)
    Infrastructure::ModelFactories.send(model_id) rescue
      Smolagents.model(:openai)
                .base_url(Infrastructure::Endpoints.const_get(endpoint.upcase))
                .id(model_id)
                .build
  end
end
```

#### 2. SSE Event Stream

```ruby
# lib/event_broadcaster.rb

class EventBroadcaster
  def initialize(response)
    @response = response
  end

  def send(type, data)
    @response << "event: #{type}\n"
    @response << "data: #{data.to_json}\n\n"
  end

  def close
    @response << "event: close\n"
    @response << "data: {}\n\n"
  end
end
```

#### 3. Sinatra Routes

```ruby
# app.rb

require 'sinatra'
require 'sinatra/streaming'

get '/' do
  erb :playground
end

get '/swarm' do
  erb :swarm
end

get '/infrastructure' do
  @health = Infrastructure::HealthChecker.new.check_all
  erb :infrastructure
end

# Agent execution with SSE
get '/agent/run', provides: 'text/event-stream' do
  stream(:keep_open) do |out|
    broadcaster = EventBroadcaster.new(out)

    config = {
      model: params[:model],
      endpoint: params[:endpoint],
      tools: params[:tools]&.split(',')&.map(&:to_sym),
      persona: params[:persona]&.to_sym,
      max_steps: params[:max_steps]&.to_i
    }

    agent = DemoAgent.new(config, stream: broadcaster)
    agent.run(params[:task])

    broadcaster.close
  end
end

# Health check API
get '/api/health' do
  content_type :json
  Infrastructure::HealthChecker.new.check_all.to_json
end
```

#### 4. Frontend: Event Stream Controller (Stimulus)

```javascript
// public/js/controllers/event_stream_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "tokenCount", "timer"]

  connect() {
    this.steps = []
    this.tokens = 0
    this.startTime = null
  }

  run(event) {
    event.preventDefault()
    const form = event.target
    const params = new URLSearchParams(new FormData(form))

    this.outputTarget.innerHTML = ''
    this.startTime = Date.now()
    this.updateTimer()

    const source = new EventSource(`/agent/run?${params}`)

    source.addEventListener('step_start', (e) => {
      const data = JSON.parse(e.data)
      this.addStep(data, 'thinking')
    })

    source.addEventListener('tool_call', (e) => {
      const data = JSON.parse(e.data)
      this.addStep(data, 'tool')
    })

    source.addEventListener('step_complete', (e) => {
      const data = JSON.parse(e.data)
      this.updateStep(data)
      this.tokens += data.tokens || 0
      this.tokenCountTarget.textContent = this.tokens
    })

    source.addEventListener('complete', (e) => {
      const data = JSON.parse(e.data)
      this.addFinalAnswer(data)
      this.stopTimer()
      source.close()
    })

    source.addEventListener('error', (e) => {
      this.addError(JSON.parse(e.data))
      source.close()
    })
  }

  addStep(data, type) {
    const stepHtml = this.renderStep(data, type)
    this.outputTarget.insertAdjacentHTML('beforeend', stepHtml)
  }

  renderStep(data, type) {
    const icons = { thinking: '💭', tool: '🔧', answer: '✅' }
    return `
      <div class="step ${type} animate-fade-in">
        <span class="icon">${icons[type]}</span>
        <div class="content">
          <div class="label">${data.label || type}</div>
          <div class="detail">${data.detail || ''}</div>
        </div>
      </div>
    `
  }
}
```

---

## Visual Design

### Color Palette

```css
:root {
  --ruby-red: #CC342D;
  --ruby-dark: #8B0000;
  --success: #10B981;
  --warning: #F59E0B;
  --info: #3B82F6;
  --bg-dark: #1F2937;
  --bg-darker: #111827;
  --text-primary: #F9FAFB;
  --text-secondary: #9CA3AF;
}
```

### Animation Guidelines

- **Steps appear**: Fade in + slide up (200ms)
- **Progress bars**: Smooth width transitions
- **Token counter**: Number animation (count up)
- **Errors**: Subtle shake + red glow
- **Success**: Green pulse on completion

### Typography

- **Headers**: Inter or SF Pro (system)
- **Code**: JetBrains Mono or Fira Code
- **Body**: System UI stack

---

## Demo Script

### For the Morning Meeting

1. **Open with Infrastructure Dashboard** (30s)
   - "Here's our distributed compute - 3 machines, 15+ models"
   - Show health status, latency numbers
   - "All running on local hardware, no cloud API costs"

2. **Agent Playground Demo** (2min)
   - Build a simple researcher agent (3 clicks)
   - Run: "Find the top 3 features in Ruby 3.3"
   - Watch steps stream in real-time
   - Point out: token efficiency, execution time, code preview

3. **Research Swarm Demo** (2min)
   - "Now let's see multiple agents working together"
   - Run a complex research query
   - Watch parallel execution visualization
   - Show synthesis of multiple perspectives

4. **Code Beauty Moment** (30s)
   - Show the generated Ruby code
   - "This is what developers write - clean, readable, powerful"

5. **Q&A** (flexible)

---

## Implementation Timeline

### Day 1: Foundation

| Task | Time |
|------|------|
| Sinatra skeleton + routes | 2h |
| Tailwind + basic layout | 1h |
| Infrastructure dashboard (static) | 2h |
| SSE streaming foundation | 2h |

### Day 2: Agent Playground

| Task | Time |
|------|------|
| Agent builder form | 2h |
| Event stream integration | 3h |
| Step visualization | 2h |
| Code preview panel | 1h |

### Day 3: Swarm + Polish

| Task | Time |
|------|------|
| Research swarm page | 3h |
| Swarm visualization | 2h |
| Animations + polish | 2h |
| Demo rehearsal | 1h |

---

## Quick Start (for development)

```bash
# Create demo directory
mkdir -p demo/{lib,views,public/{css,js}}

# Gemfile
cat > demo/Gemfile << 'EOF'
source "https://rubygems.org"

gem "sinatra", "~> 4.0"
gem "sinatra-contrib"
gem "puma"
gem "rack"

# Add path to smolagents
gem "smolagents", path: ".."
EOF

# Run
cd demo && bundle install && bundle exec ruby app.rb
```

---

## Open Questions

1. **Authentication?** - Probably none for demo, but could add simple token
2. **Persistence?** - Store runs for replay? Or ephemeral demo only?
3. **Mobile responsive?** - Nice to have but not critical for demo
4. **Dark mode only?** - Matches "hacker" aesthetic, easier to design

---

## Success Criteria

- [ ] Stakeholders say "wow" at least twice
- [ ] Agent builder works in under 30 seconds
- [ ] Real-time streaming feels smooth and magical
- [ ] Code preview makes developers want to use it
- [ ] Infrastructure dashboard shows the power of distributed compute
- [ ] No crashes during demo

---

*Plan v1.0 - Ready for review*
