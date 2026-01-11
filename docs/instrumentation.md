# Instrumentation Guide

Smolagents includes built-in instrumentation hooks for collecting metrics from agent execution. This enables production monitoring with systems like Prometheus, StatsD, and Datadog.

## Overview

The instrumentation system emits events for key operations:
- `smolagents.agent.run` - Agent execution
- `smolagents.agent.step` - Individual agent step
- `smolagents.model.generate` - LLM API call
- `smolagents.tool.call` - Tool execution
- `smolagents.executor.execute` - Code execution

Each event includes:
- `duration` - Execution time in seconds
- `error` - Exception class name (if an error occurred)
- Additional context (model_id, tool_name, etc.)

## Setup

Set a subscriber to receive instrumentation events:

```ruby
Smolagents::Instrumentation.subscriber = ->(event, payload) do
  # Process the event
  puts "Event: #{event}"
  puts "Duration: #{payload[:duration]}s"
  puts "Error: #{payload[:error]}" if payload[:error]
end
```

## Integration Examples

### Prometheus

```ruby
require 'prometheus/client'

registry = Prometheus::Client.registry
step_duration = registry.histogram(:smolagents_step_duration_seconds, 'Step duration')
model_calls = registry.counter(:smolagents_model_calls_total, 'Model API calls')

Smolagents::Instrumentation.subscriber = ->(event, payload) do
  case event
  when 'smolagents.agent.step'
    step_duration.observe(payload[:duration])
  when 'smolagents.model.generate'
    model_calls.increment(labels: { model: payload[:model_id] })
  end
end
```

### StatsD

```ruby
require 'statsd-instrument'

Smolagents::Instrumentation.subscriber = ->(event, payload) do
  StatsD.measure("smolagents.#{event}", payload[:duration] * 1000)
  StatsD.increment("smolagents.#{event}.count")
end
```

### Datadog

```ruby
require 'datadog/statsd'

statsd = Datadog::Statsd.new('localhost', 8125)

Smolagents::Instrumentation.subscriber = ->(event, payload) do
  statsd.timing("smolagents.#{event}", payload[:duration] * 1000)
  statsd.increment("smolagents.#{event}.count")
end
```

## Performance Impact

When no subscriber is set, instrumentation has **zero performance overhead**.

With a subscriber, the overhead is minimal:
- Two monotonic clock reads per operation
- One hash merge operation
- One subscriber callback

## Best Practices

1. **Keep subscribers fast** - Instrumentation runs inline
2. **Handle errors** - Wrap subscriber code in error handling
3. **Use appropriate aggregations** - Histograms for durations, counters for events
4. **Add relevant labels** - Include model_id, tool_name for better filtering
5. **Monitor error rates** - Track both calls and errors
6. **Set up alerts** - Alert on high error rates or slow durations
