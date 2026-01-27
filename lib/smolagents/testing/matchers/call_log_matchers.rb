module Smolagents
  module Testing
    module Matchers
      # Matchers for CallLog and agent execution verification.
      #
      # These matchers provide powerful assertions for testing agent behavior
      # based on recorded call logs.
      #
      # @example Tool call assertions
      #   expect(agent.call_log).to have_called_tool(:search)
      #   expect(agent.call_log).to have_called_tool(:search).with(query: "Ruby")
      #   expect(agent.call_log).to have_called_tool(:search).times(2)
      #
      # @example Step assertions
      #   expect(agent.call_log).to have_completed_step(1)
      #   expect(agent.call_log).to have_logged_steps(3)
      #
      # rubocop:disable Metrics/ModuleLength -- RSpec matcher definitions are verbose by nature
      module CallLogMatchers
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- matcher DSL requires setup
        # rubocop:disable Metrics/BlockLength -- RSpec matchers need block definitions
        def self.included(base)
          return unless defined?(RSpec::Matchers)

          base.class_eval do
            # Matcher for verifying a tool was called.
            #
            # @example Basic usage
            #   expect(call_log).to have_called_tool(:search)
            #
            # @example With arguments
            #   expect(call_log).to have_called_tool(:search).with(query: "Ruby")
            #
            # @example Specific number of times
            #   expect(call_log).to have_called_tool(:search).times(2)
            RSpec::Matchers.define :have_called_tool do |tool_name|
              match do |call_log|
                @tool_name = tool_name

                calls = find_tool_calls(call_log, tool_name)
                return false if calls.empty?

                calls = filter_by_args(calls) if @expected_args
                return false if calls.empty?
                return false if @expected_times && calls.size != @expected_times

                calls.any?
              end

              chain :with do |args = {}|
                @expected_args = args
              end

              chain :times do |count|
                @expected_times = count
              end

              failure_message do |call_log|
                actual = find_tool_calls(call_log, @tool_name)
                msg = "expected call_log to have called tool :#{@tool_name}"
                msg += " with #{@expected_args.inspect}" if @expected_args
                msg += " #{@expected_times} times" if @expected_times
                msg + ", but #{describe_actual(actual)}"
              end

              define_method(:find_tool_calls) do |call_log, name|
                call_log.tool_calls.select { |c| c.name == name.to_sym }
              end

              define_method(:filter_by_args) do |calls|
                calls.select do |c|
                  @expected_args.all? { |k, v| match_value(c.args[k], v) }
                end
              end

              define_method(:match_value) do |actual, expected|
                case expected
                when Regexp then actual.to_s.match?(expected)
                else actual == expected
                end
              end

              define_method(:describe_actual) do |calls|
                return "it was never called" if calls.empty?

                "got #{calls.size} calls"
              end
            end

            # Matcher for verifying a specific step completed.
            #
            # @example
            #   expect(call_log).to have_completed_step(1)
            #   expect(call_log).to have_completed_step(1).with_outcome(:success)
            RSpec::Matchers.define :have_completed_step do |step_number|
              match do |call_log|
                @step_number = step_number
                step = call_log.steps.find { |s| s.args[:step_number] == step_number }
                return false unless step
                return true unless @expected_outcome

                step.metadata[:outcome] == @expected_outcome
              end

              chain :with_outcome do |outcome|
                @expected_outcome = outcome
              end

              failure_message do |call_log|
                steps = call_log.steps.map { |s| s.args[:step_number] }
                "expected step #{@step_number} but only found: #{steps.inspect}"
              end
            end

            # Matcher for verifying total logged step count.
            #
            # @example
            #   expect(call_log).to have_logged_steps(3)
            RSpec::Matchers.define :have_logged_steps do |expected_count|
              match do |call_log|
                @expected = expected_count
                call_log.steps.size == @expected
              end

              failure_message do |call_log|
                "expected #{@expected} logged steps, got #{call_log.steps.size}"
              end
            end

            # Matcher for verifying a pattern exists in call log.
            #
            # @example
            #   expect(call_log).to have_entry(tool: :search)
            #   expect(call_log).to have_entry(tool: :search, args: { query: /Ruby/ })
            RSpec::Matchers.define :have_entry do |pattern|
              match do |call_log|
                call_log.include?(pattern)
              end

              failure_message do
                "expected call_log to have entry matching #{pattern.inspect}"
              end
            end

            # Matcher for verifying tool call sequence.
            #
            # @example
            #   expect(call_log).to have_called_tools_in_order(:search, :fetch, :final_answer)
            RSpec::Matchers.define :have_called_tools_in_order do |*tool_names|
              match do |call_log|
                @expected = tool_names.map(&:to_sym)
                actual_names = call_log.tool_calls.map(&:name)
                subsequence?(actual_names, @expected)
              end

              failure_message do |call_log|
                actual = call_log.tool_calls.map(&:name)
                "expected tools #{@expected.inspect} in order, got #{actual.inspect}"
              end

              define_method(:subsequence?) do |haystack, needles|
                idx = 0
                needles.each do |needle|
                  idx = haystack[idx..].index(needle)
                  return false unless idx

                  idx += 1
                end
                true
              end
            end
          end
        end
        # rubocop:enable Metrics/BlockLength
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
