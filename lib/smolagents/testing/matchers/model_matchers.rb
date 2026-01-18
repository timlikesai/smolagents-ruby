module Smolagents
  module Testing
    module Matchers
      # Matchers for verifying model interactions.
      module ModelMatchers
        # Registers model matchers when included.
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:disable Metrics/BlockLength -- RSpec matcher DSL requires single block
        def self.included(base)
          return unless defined?(RSpec::Matchers)

          base.class_eval do
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

            # Matcher for verifying model received expected messages.
            #
            # @example
            #   expect(model).to have_received_message(containing: "search")
            #   expect(model).to have_received_message(role: :user)
            RSpec::Matchers.define :have_received_message do |options = {}|
              match do |model|
                @options = options
                messages = model.respond_to?(:user_messages_sent) ? model.user_messages_sent : []
                messages.any? { |msg| matches_role?(msg) && matches_content?(msg) }
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
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
        # rubocop:enable Metrics/BlockLength
      end
    end
  end
end
