module Smolagents
  module Testing
    # Custom RSpec matchers for testing smolagents.
    #
    # Include this module in your RSpec configuration to get access to
    # agent-specific matchers that make tests more expressive.
    #
    # @example RSpec integration
    #   require "smolagents/testing"
    #
    #   RSpec.configure do |config|
    #     config.include Smolagents::Testing::Matchers
    #   end
    #
    # @example Using matchers
    #   describe "MyAgent" do
    #     it "completes successfully" do
    #       expect(agent).to complete_successfully.with_task("What is 2+2?")
    #     end
    #
    #     it "calls the search tool" do
    #       expect(spy_tool).to call_tool("search").with_arguments(query: "Ruby")
    #     end
    #
    #     it "exhausts all responses" do
    #       expect(model).to be_exhausted
    #     end
    #   end
    #
    # @see Helpers Helper methods for setting up tests
    # @see MockModel Mock model for deterministic testing
    module Matchers # rubocop:disable Metrics/ModuleLength
      # Defines all matchers when included in a test context.
      #
      # @param base [Module] The module including Matchers
      def self.included(base) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        return unless defined?(RSpec::Matchers)

        base.class_eval do # rubocop:disable Metrics/BlockLength
          # Matcher for verifying agent completes successfully.
          #
          # @example Basic usage
          #   expect(agent).to complete_successfully.with_task("question")
          #
          # @example With result inspection
          #   expect(result).to complete_successfully
          RSpec::Matchers.define :complete_successfully do
            match do |agent_or_result|
              @result = agent_or_result.respond_to?(:run) ? agent_or_result.run(@task) : agent_or_result
              !@result.nil? && !@result.is_a?(Exception)
            end

            chain(:with_task) { |task| @task = task }

            failure_message do
              "expected agent to complete successfully but got: #{@result.inspect}"
            end
          end

          # Matcher for verifying tool was called with specific arguments.
          #
          # @example
          #   expect(spy_tool).to call_tool("search").with_arguments(query: "Ruby")
          RSpec::Matchers.define :call_tool do |tool_name|
            match do |actual|
              @tool_name = tool_name
              @actual_calls = actual.is_a?(SpyTool) ? actual.calls : actual
              @actual_calls.any? do |call|
                call.is_a?(Hash) && (!@expected_args || @expected_args.all? do |k, v|
                  call[k] == v || call[k.to_s] == v
                end)
              end
            end

            chain(:with_arguments) { |args| @expected_args = args }

            failure_message do
              <<~MSG.gsub(/\s+/, " ").strip
                expected tool call to #{@tool_name} with #{@expected_args.inspect},
                but got: #{@actual_calls.inspect}
              MSG
            end
          end

          # Matcher for verifying model received expected messages.
          #
          # @example
          #   expect(model).to have_received_message(containing: "search")
          #   expect(model).to have_received_message(role: :user)
          RSpec::Matchers.define :have_received_message do |options = {}|
            match do |model|
              @options = options
              messages = model.respond_to?(:user_messages_sent) ? model.user_messages_sent : []

              messages.any? do |msg|
                matches_role?(msg) && matches_content?(msg)
              end
            end

            failure_message do
              "expected model to have received message matching #{@options.inspect}"
            end

            define_method(:matches_role?) do |msg|
              return true unless @options[:role]

              msg.role == @options[:role] || msg.role.to_s == @options[:role].to_s
            end

            define_method(:matches_content?) do |msg|
              return true unless @options[:containing]

              msg.content&.include?(@options[:containing])
            end
          end

          # Matcher for verifying model exhausted all queued responses.
          #
          # @example
          #   expect(model).to be_exhausted
          RSpec::Matchers.define :be_exhausted do
            match(&:exhausted?)

            failure_message do |mock|
              "expected mock to be exhausted but has #{mock.remaining_responses} responses remaining"
            end
          end

          # Matcher for verifying model received specific number of calls.
          #
          # @example
          #   expect(model).to have_received_calls(3)
          RSpec::Matchers.define :have_received_calls do |expected|
            match { |mock| mock.call_count == expected }

            failure_message do |mock|
              "expected #{expected} calls, got #{mock.call_count}"
            end
          end

          # Matcher for verifying model received a specific prompt.
          #
          # @example
          #   expect(model).to have_seen_prompt("search for Ruby")
          RSpec::Matchers.define :have_seen_prompt do |expected|
            match do |mock|
              mock.user_messages_sent.any? { |m| m.content&.include?(expected) }
            end

            failure_message do |mock|
              prompts = mock.user_messages_sent.map { |m| m.content&.truncate(50) }
              "expected '#{expected}' in user messages: #{prompts}"
            end
          end

          # Matcher for verifying model received a system prompt.
          #
          # @example
          #   expect(model).to have_seen_system_prompt
          RSpec::Matchers.define :have_seen_system_prompt do
            match { |mock| mock.calls_with_system_prompt.any? }

            failure_message { "expected system prompt in calls but none found" }
          end

          # Matcher for verifying agent result contains expected output.
          #
          # @example
          #   expect(result).to have_output(containing: "42")
          #   expect(result).to have_output(matching: /\d+/)
          RSpec::Matchers.define :have_output do |options = {}|
            match do |result|
              @options = options
              output = extract_output(result)
              return false unless output

              matches_containing?(output) && matches_pattern?(output)
            end

            failure_message do
              "expected result to have output matching #{@options.inspect}"
            end

            define_method(:extract_output) do |result|
              case result
              when String then result
              when Hash then result[:output] || result["output"]
              else result.respond_to?(:output) ? result.output : result.to_s
              end
            end

            define_method(:matches_containing?) do |output|
              return true unless @options[:containing]

              output.to_s.include?(@options[:containing])
            end

            define_method(:matches_pattern?) do |output|
              return true unless @options[:matching]

              @options[:matching].match?(output.to_s)
            end
          end

          # Matcher for verifying step count.
          #
          # @example
          #   expect(result).to have_steps(3)
          #   expect(result).to have_steps(at_most: 5)
          #   expect(result).to have_steps(at_least: 2)
          RSpec::Matchers.define :have_steps do |count_or_options|
            match do |result|
              @expected = count_or_options
              steps = result.respond_to?(:steps) ? result.steps : []
              @actual_count = steps.size

              case count_or_options
              when Integer
                @actual_count == count_or_options
              when Hash
                check_step_constraints(count_or_options)
              else
                false
              end
            end

            failure_message do
              "expected #{@expected.inspect} steps but got #{@actual_count}"
            end

            define_method(:check_step_constraints) do |options|
              return false if options[:at_most] && (@actual_count > options[:at_most])
              return false if options[:at_least] && (@actual_count < options[:at_least])

              true
            end
          end
        end
      end
    end
  end
end
