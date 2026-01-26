module Smolagents
  module Testing
    module Matchers
      # Matcher for TestResult/TestRun pass state
      #
      # @example
      #   expect(result).to be_passed
      #   expect(run).to be_passed
      RSpec::Matchers.define :be_passed do
        match do |actual|
          actual.respond_to?(:passed?) ? actual.passed? : actual.passed
        end

        failure_message do |actual|
          if actual.respond_to?(:pass_rate)
            "expected test run to pass (pass_rate: #{actual.pass_rate}, threshold: #{actual.threshold})"
          else
            "expected test result to pass, got error: #{actual.error}"
          end
        end
      end

      # Matcher for pass rate threshold
      #
      # @example
      #   expect(run).to have_pass_rate(at_least: 0.9)
      #   expect(run).to have_pass_rate(exactly: 1.0)
      RSpec::Matchers.define :have_pass_rate do |options|
        match do |actual|
          rate = actual.pass_rate
          if options.is_a?(Hash)
            if options[:at_least]
              rate >= options[:at_least]
            elsif options[:exactly]
              (rate - options[:exactly]).abs < 0.001
            elsif options[:at_most]
              rate <= options[:at_most]
            else
              true
            end
          else
            rate >= options # default to at_least
          end
        end

        failure_message do |actual|
          "expected pass_rate #{format_expectation(options)}, got #{actual.pass_rate}"
        end

        def format_expectation(options)
          return ">= #{options}" unless options.is_a?(Hash)
          return ">= #{options[:at_least]}" if options[:at_least]
          return "== #{options[:exactly]}" if options[:exactly]
          return "<= #{options[:at_most]}" if options[:at_most]

          options.to_s
        end
      end

      # Matcher for efficiency
      #
      # @example
      #   expect(result).to have_efficiency(above: 0.5)
      RSpec::Matchers.define :have_efficiency do |options|
        match do |actual|
          eff = actual.efficiency
          if options.is_a?(Hash)
            if options[:above]
              eff > options[:above]
            elsif options[:below]
              eff < options[:below]
            else
              true
            end
          else
            eff >= options
          end
        end
      end

      # Matcher for step count
      #
      # @example
      #   expect(result).to have_completed_in(steps: 3)
      #   expect(result).to have_completed_in(steps: 1..5)
      RSpec::Matchers.define :have_completed_in do |options|
        match do |actual|
          steps = actual.steps
          expected = options[:steps]
          case expected
          when Range then expected.include?(steps)
          when Integer then steps == expected
          else steps <= expected
          end
        end

        failure_message do |actual|
          "expected to complete in #{options[:steps]} steps, got #{actual.steps}"
        end
      end

      # Matcher for capabilities
      #
      # @example
      #   expect(score).to have_capability(:tool_use)
      RSpec::Matchers.define :have_capability do |capability|
        match do |actual|
          actual.capabilities_passed.include?(capability)
        end

        failure_message do |actual|
          "expected model to have #{capability}, passed: #{actual.capabilities_passed}"
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include Smolagents::Testing::Matchers
end
