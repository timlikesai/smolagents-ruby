# frozen_string_literal: true

require "json"

module Smolagents
  # Pattern matching utilities and helpers for working with agent responses.
  # Provides Ruby 3.0+ pattern matching support with useful extractors.
  #
  # @example Matching ChatMessage types
  #   case message
  #   in ChatMessage[role: :assistant, tool_calls: Array => calls]
  #     handle_tool_calls(calls)
  #   in ChatMessage[role: :assistant, content: String => text]
  #     handle_text(text)
  #   end
  #
  # @example Matching ActionStep results
  #   case step
  #   in ActionStep[is_final_answer: true, output: result]
  #     finalize(result)
  #   in ActionStep[error: String => error_msg]
  #     handle_error(error_msg)
  #   in ActionStep[observations: obs]
  #     continue_with(obs)
  #   end
  module PatternMatching
    # Extract code blocks from text with pattern matching.
    #
    # @param text [String] text to extract from
    # @return [String, nil] extracted code or nil
    #
    # @example
    #   code = extract_code(response_text)
    #   puts "Code: #{code}" if code
    def self.extract_code(text)
      # Try ruby code blocks first
      if (match = text.match(/```ruby\n(.+?)```/m))
        return match[1].strip
      end

      # Then generic code blocks
      if (match = text.match(/```\n(.+?)```/m))
        return match[1].strip
      end

      # Finally HTML-style code tags
      if (match = text.match(/<code>(.+?)<\/code>/m))
        return match[1].strip
      end

      nil
    end

    # Extract JSON from text with pattern matching.
    #
    # @param text [String] text containing JSON
    # @return [Hash, nil] parsed JSON or nil
    #
    # @example
    #   data = extract_json(response)
    #   puts "Got: #{data}" if data
    def self.extract_json(text)
      # Try JSON code blocks first
      if (match = text.match(/```json\n(.+?)```/m))
        return JSON.parse(match[1])
      end

      # Then try to find JSON in plain text (greedy to get nested structures)
      if (match = text.match(/\{.+\}/m))
        return JSON.parse(match[0])
      end

      nil
    rescue JSON::ParserError
      nil
    end

    # Match against common error patterns.
    #
    # @param error [Exception] error to match
    # @return [Symbol] error category
    #
    # @example
    #   category = categorize_error(error)
    #   case category
    #   when :rate_limit
    #     wait_and_retry
    #   when :timeout
    #     use_shorter_timeout
    #   when :authentication
    #     refresh_credentials
    #   end
    def self.categorize_error(error)
      # Check error class first
      return :rate_limit if defined?(Faraday::TooManyRequestsError) && error.is_a?(Faraday::TooManyRequestsError)
      return :timeout if defined?(Faraday::TimeoutError) && error.is_a?(Faraday::TimeoutError)
      return :authentication if defined?(Faraday::UnauthorizedError) && error.is_a?(Faraday::UnauthorizedError)
      return :client_error if defined?(Faraday::ClientError) && error.is_a?(Faraday::ClientError)
      return :server_error if defined?(Faraday::ServerError) && error.is_a?(Faraday::ServerError)

      # Check message patterns
      message = error.message
      return :rate_limit if message =~ /rate limit/i
      return :timeout if message =~ /timeout/i
      return :authentication if message =~ /unauthorized|invalid.*key/i
      return :client_error if message =~ /4\d{2}/i
      return :server_error if message =~ /5\d{2}/i

      :unknown
    end

    # Pattern match tool execution results.
    #
    # @param result [Object] tool execution result
    # @yield [matcher] block to define patterns
    # @return [Object] result of matched block
    #
    # @example
    #   match_tool_result(result) do |m|
    #     m.on(success: true) { |r| puts "Success: #{r[:output]}" }
    #     m.on(success: false) { |r| puts "Failed: #{r[:error]}" }
    #     m.otherwise { puts "Unknown" }
    #   end
    def self.match_tool_result(result)
      matcher = ToolResultMatcher.new(result)
      yield matcher
      matcher.execute
    end

    # Internal matcher for tool results.
    # Simple pattern matching helper for Ruby.
    # @private
    class ToolResultMatcher
      def initialize(result)
        @result = result
        @patterns = []
        @otherwise_handler = nil
      end

      # Add a pattern to match.
      #
      # @param pattern [Hash] pattern to match against result
      # @yield [result] handler for matched pattern
      def on(pattern, &block)
        @patterns << [pattern, block]
      end

      # Handler when no patterns match.
      #
      # @yield handler block
      def otherwise(&block)
        @otherwise_handler = block
      end

      # Execute the first matching pattern.
      #
      # @return [Object] result of matched handler
      def execute
        @patterns.each do |pattern, handler|
          if matches?(pattern, @result)
            return handler.call(@result)
          end
        end

        @otherwise_handler&.call
      end

      private

      # Check if pattern matches result.
      #
      # @param pattern [Hash] pattern to match
      # @param result [Hash, Object] result to check
      # @return [Boolean]
      def matches?(pattern, result)
        return false unless result.is_a?(Hash)

        pattern.all? do |key, expected_value|
          actual_value = result[key]

          # Type checking for classes
          if expected_value.is_a?(Class)
            actual_value.is_a?(expected_value)
          else
            actual_value == expected_value
          end
        end
      end
    end
  end

  # Refinement for adding pattern matching to ChatMessage.
  module ChatMessagePatterns
    refine ChatMessage do
      # Deconstruct for pattern matching.
      # @example
      #   case message
      #   in ChatMessage[role: :system, content:]
      #     # ...
      #   end
      def deconstruct_keys(keys)
        {
          role: role,
          content: content,
          tool_calls: tool_calls,
          raw: raw,
          token_usage: token_usage
        }
      end
    end
  end

  # Refinement for adding pattern matching to ActionStep.
  module ActionStepPatterns
    refine ActionStep do
      # Deconstruct for pattern matching.
      # @example
      #   case step
      #   in ActionStep[step_number:, is_final_answer: true, output:]
      #     # ...
      #   end
      def deconstruct_keys(keys)
        {
          step_number: step_number,
          timing: timing,
          model_input_messages: model_input_messages,
          tool_calls: tool_calls,
          error: error,
          model_output_message: model_output_message,
          model_output: model_output,
          code_action: code_action,
          observations: observations,
          action_output: action_output,
          token_usage: token_usage,
          is_final_answer: is_final_answer
        }
      end
    end
  end
end
