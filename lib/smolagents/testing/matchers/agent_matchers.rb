module Smolagents
  module Testing
    module Matchers
      # Matchers for verifying agent behavior.
      module AgentMatchers
        # Registers agent matchers when included.
        # rubocop:disable Metrics/MethodLength -- RSpec matcher DSL requires single block
        def self.included(base)
          return unless defined?(RSpec::Matchers)

          base.class_eval do
            # Matcher for verifying agent completes successfully.
            #
            # @example Basic usage
            #   expect(agent).to complete_successfully.with_task("question")
            #
            # @example With result inspection
            #   expect(result).to complete_successfully
            RSpec::Matchers.define :complete_successfully do
              match do |agent_or_result|
                @result = if agent_or_result.respond_to?(:run)
                            agent_or_result.run(@task)
                          else
                            agent_or_result
                          end
                !@result.nil? && !@result.is_a?(Exception)
              end

              chain(:with_task) { |task| @task = task }

              failure_message do
                "expected agent to complete successfully but got: #{@result.inspect}"
              end
            end
          end
        end
        # rubocop:enable Metrics/MethodLength
      end
    end
  end
end
