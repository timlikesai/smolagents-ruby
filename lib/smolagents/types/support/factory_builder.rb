module Smolagents
  module Types
    module TypeSupport
      # DSL for defining factory methods on Data.define types.
      #
      # Factory methods create instances with preset values, reducing boilerplate
      # and improving code readability. Extend (not include) to add class methods.
      #
      # @example Basic factory
      #   EvaluationResult = Data.define(:status, :answer, :confidence) do
      #     extend TypeSupport::FactoryBuilder
      #
      #     factory :achieved, status: :goal_achieved, confidence: 0.9
      #     factory :stuck, status: :stuck, confidence: 0.3
      #   end
      #
      #   EvaluationResult.achieved(answer: "42")
      #   # => #<data EvaluationResult status=:goal_achieved, answer="42", confidence=0.9>
      #
      # @example Factory with all defaults
      #   TokenUsage = Data.define(:input_tokens, :output_tokens) do
      #     extend TypeSupport::FactoryBuilder
      #
      #     factory :zero, input_tokens: 0, output_tokens: 0
      #   end
      #
      #   TokenUsage.zero
      #   # => #<data TokenUsage input_tokens=0, output_tokens=0>
      #
      # @example Factory with required args
      #   Result = Data.define(:status, :value, :error) do
      #     extend TypeSupport::FactoryBuilder
      #
      #     factory :success, status: :ok, error: nil
      #     factory :failure, status: :failed, value: nil
      #   end
      #
      #   Result.success(value: 42)       # value is required
      #   Result.failure(error: "oops")   # error is required
      #
      module FactoryBuilder
        # Defines a factory method with preset defaults.
        #
        # @param name [Symbol] Factory method name
        # @param defaults [Hash{Symbol => Object}] Default values for members
        # @return [void]
        #
        # @example
        #   factory :empty, items: [], count: 0
        def factory(name, **defaults)
          define_singleton_method(name) do |**overrides|
            new(**defaults, **overrides)
          end
        end

        # Defines multiple factories at once.
        #
        # @param factories [Hash{Symbol => Hash}] Factory name to defaults mapping
        # @return [void]
        #
        # @example
        #   factories achieved: { status: :goal_achieved, confidence: 0.9 },
        #             stuck: { status: :stuck, confidence: 0.3 }
        def factories(**factory_defs)
          factory_defs.each { |name, defaults| factory(name, **defaults) }
        end
      end
    end
  end
end
