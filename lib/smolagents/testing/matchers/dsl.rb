module Smolagents
  module Testing
    module Matchers
      # DSL for generating similar matchers with shared behavior.
      module DSL
        # Defines a simple predicate matcher.
        #
        # @param matcher_name [Symbol] RSpec matcher name
        # @param predicate [Symbol] Method to call on actual object
        # @param failure_msg [Proc, String] Failure message generator
        def define_predicate_matcher(matcher_name, predicate, failure_msg: nil)
          RSpec::Matchers.define matcher_name do
            match { |actual| actual.public_send(predicate) }

            failure_message do |actual|
              if failure_msg.is_a?(Proc) then failure_msg.call(actual)
              elsif failure_msg then failure_msg
              else "expected #{actual.inspect} to #{matcher_name.to_s.tr("_", " ")}"
              end
            end
          end
        end

        # Defines a matcher that compares against thresholds.
        #
        # @param matcher_name [Symbol] RSpec matcher name
        # @param value_method [Symbol] Method to get value from actual
        # @param _default_comparison [Symbol] Reserved for future use
        def define_threshold_matcher(matcher_name, value_method, _default_comparison: :at_least)
          RSpec::Matchers.define matcher_name do |options|
            match do |actual|
              @actual_value = actual.public_send(value_method)
              ThresholdComparison.compare(@actual_value, options)
            end

            failure_message do
              "expected #{value_method} #{ThresholdComparison.format(options)}, got #{@actual_value}"
            end
          end
        end

        # Defines a matcher that checks content contains/matches patterns.
        #
        # @param matcher_name [Symbol] RSpec matcher name
        # @param extractor [Proc] Extracts content from actual object
        def define_content_matcher(matcher_name, &)
          RSpec::Matchers.define matcher_name do |options = {}|
            match do |result|
              @options = options
              content = instance_exec(result, &)
              content && ContentMatch.matches?(content, options)
            end

            failure_message { "expected #{matcher_name} matching #{@options.inspect}" }
          end
        end
      end

      # Threshold comparison logic for matchers.
      module ThresholdComparison
        module_function

        # rubocop:disable Metrics/AbcSize -- comparison dispatch table
        def compare(value, opts)
          return value >= opts unless opts.is_a?(Hash)

          comparisons = { at_least: ->(v, t) { v >= t }, at_most: ->(v, t) { v <= t },
                          exactly: ->(v, t) { (v - t).abs < 0.001 },
                          above: ->(v, t) { v > t }, below: ->(v, t) { v < t } }
          key = (comparisons.keys & opts.keys).first
          key ? comparisons[key].call(value, opts[key]) : true
        end
        # rubocop:enable Metrics/AbcSize

        def format(opts)
          return ">= #{opts}" unless opts.is_a?(Hash)

          formats = { at_least: ">=", at_most: "<=", exactly: "==", above: ">", below: "<" }
          key = (formats.keys & opts.keys).first
          key ? "#{formats[key]} #{opts[key]}" : opts.to_s
        end
      end

      # Content matching logic for matchers.
      module ContentMatch
        module_function

        def matches?(content, options)
          matches_containing?(content, options) && matches_pattern?(content, options)
        end

        def matches_containing?(content, options)
          !options[:containing] || content.to_s.include?(options[:containing])
        end

        def matches_pattern?(content, options)
          !options[:matching] || options[:matching].match?(content.to_s)
        end
      end
    end
  end
end
