# Experiment: Failure Recovery
#
# Test how agents handle failures gracefully:
# - Tool failures (exceptions, timeouts, invalid responses)
# - Model errors (rate limits, server errors)
# - Invalid inputs (malformed data, edge cases)
#
# A resilient agent should:
# 1. Retry transient failures
# 2. Provide meaningful error messages
# 3. Fall back to alternative approaches
# 4. Complete tasks despite partial failures

require_relative "../lib/experiment"
require_relative "../lib/infrastructure"

LiveExperiments::Experiment.define(:failure_recovery) do
  description "Test agent resilience to failures and error recovery"

  models do
    use :fast, :fast_model
    use :resilient, :resilient_fast_model  # Has fallback chain
  end

  tools do
    # Tool that succeeds on retry
    mock :flaky_api, "Call a flaky external API", query: String do |query:|
      @flaky_call_count ||= 0
      @flaky_call_count += 1

      if @flaky_call_count <= 1
        raise Faraday::ServerError, "Server temporarily unavailable"
      end

      "API response for '#{query}': Success after retry"
    end

    # Tool that returns partial data
    # NOTE: Return string-keyed hashes for LLM compatibility
    mock :partial_data, "Fetch data that may be incomplete", id: String do |id:|
      case id
      when /complete/i
        { "status" => "complete", "data" => { "name" => "Test Item", "value" => 42 } }
      when /partial/i
        { "status" => "partial", "data" => { "name" => "Incomplete" }, "warning" => "Some fields missing" }
      when /empty/i
        { "status" => "empty", "data" => nil, "error" => "No data found" }
      else
        { "status" => "complete", "data" => { "name" => id, "value" => rand(100) } }
      end
    end

    # Tool with variable latency
    mock :slow_service, "Call a slow external service", operation: String do |operation:|
      # Simulate variable latency (would be real sleep in production)
      latency = case operation
                when /fast/i then "50ms"
                when /slow/i then "500ms"
                when /timeout/i then "TIMEOUT (would exceed limit)"
                else "100ms"
                end

      "Completed '#{operation}' in #{latency}"
    end

    # Tool that validates input
    mock :validated_tool, "Tool with input validation", value: Integer do |value:|
      if value.negative?
        raise ArgumentError, "Value must be non-negative, got #{value}"
      elsif value > 1000
        raise ArgumentError, "Value must be <= 1000, got #{value}"
      end

      "Processed value: #{value * 2}"
    end

    # Standard calculate tool for baseline
    mock :calculate, "Calculate a mathematical expression", expression: String do |expression:|
      sanitized = expression.to_s.gsub(/[^0-9+\-*\/().\s]/, "").strip
      if sanitized.empty? || sanitized !~ /\A[\d(]/
        "Error: invalid expression"
      else
        eval(sanitized).to_s # rubocop:disable Security/Eval
      end
    rescue SyntaxError => e
      "Error: invalid syntax - #{e.message}"
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  tasks do
    # Basic recovery tests
    task "Call the flaky_api with query 'test data' - it may fail initially but should succeed on retry",
         validate: ->(output) { output.downcase.include?("success") },
         tags: [:retry, :transient_failure],
         difficulty: :medium

    # Handling partial data
    task "Fetch partial_data with id 'partial_item' and summarize what you got, noting any warnings",
         validate: ->(output) { output.downcase.include?("partial") || output.downcase.include?("incomplete") || output.downcase.include?("warning") },
         tags: [:partial_data, :graceful],
         difficulty: :easy

    task "Fetch partial_data with id 'empty_record' and explain what happened",
         validate: ->(output) { output.downcase.include?("empty") || output.downcase.include?("no data") || output.downcase.include?("error") },
         tags: [:empty_data, :error_handling],
         difficulty: :easy

    # Invalid input handling
    task "Try to use validated_tool with value -5 and explain the error",
         validate: ->(output) { output.downcase.include?("negative") || output.downcase.include?("error") || output.downcase.include?("invalid") },
         tags: [:validation, :error_handling],
         difficulty: :medium

    task "Use validated_tool with a valid value like 50 and report the result",
         validate: ->(output) { output.include?("100") }, # 50 * 2 = 100
         tags: [:validation, :success],
         difficulty: :easy

    # Multi-step with potential failures
    task "First calculate 25 * 4, then fetch partial_data for 'complete_record', and combine the results",
         validate: ->(output) { output.include?("100") && (output.downcase.include?("test") || output.downcase.include?("complete")) },
         tags: [:multi_step, :combined],
         difficulty: :medium

    # Recovery from tool errors
    task "Try to calculate 'invalid expression ###' and then calculate '10 + 5' instead if it fails",
         validate: ->(output) { output.include?("15") },
         tags: [:fallback, :error_recovery],
         difficulty: :medium

    # Explain failures clearly
    task "Call slow_service with operation 'timeout_operation' and report what happened",
         validate: ->(output) { output.downcase.include?("timeout") || output.downcase.include?("slow") || output.downcase.include?("time") },
         tags: [:timeout, :reporting],
         difficulty: :easy
  end

  config do
    iterations 2
    timeout 120
    max_steps 10
    checkpoint_every 1
  end
end
