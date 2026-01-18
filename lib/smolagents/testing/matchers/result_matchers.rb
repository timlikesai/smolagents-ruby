module Smolagents
  module Testing
    module Matchers
      # Matchers for verifying agent results.
      module ResultMatchers
        # Registers result matchers when included.
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:disable Metrics/BlockLength -- RSpec matcher DSL requires single block
        def self.included(base)
          return unless defined?(RSpec::Matchers)

          base.class_eval do
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
                when Integer then @actual_count == count_or_options
                when Hash then check_step_constraints(count_or_options)
                else false
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
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:enable Metrics/BlockLength
      end
    end
  end
end
