module Smolagents
  module Testing
    module Matchers
      # Matchers for verifying tool calls.
      module ToolMatchers
        # Registers tool matchers when included.
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        def self.included(base)
          return unless defined?(RSpec::Matchers)

          base.class_eval do
            # Matcher for verifying tool was called with specific arguments.
            #
            # @example
            #   expect(spy_tool).to call_tool("search").with_arguments(query: "Ruby")
            RSpec::Matchers.define :call_tool do |tool_name|
              match do |actual|
                @tool_name = tool_name
                @actual_calls = actual.is_a?(SpyTool) ? actual.calls : actual
                @actual_calls.any? do |call|
                  call.is_a?(Hash) && (!@expected_args || args_match?(call))
                end
              end

              chain(:with_arguments) { |args| @expected_args = args }

              failure_message do
                <<~MSG.gsub(/\s+/, " ").strip
                  expected tool call to #{@tool_name} with #{@expected_args.inspect},
                  but got: #{@actual_calls.inspect}
                MSG
              end

              define_method(:args_match?) do |call|
                @expected_args.all? do |key, value|
                  call[key] == value || call[key.to_s] == value
                end
              end
            end
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
      end
    end
  end
end
