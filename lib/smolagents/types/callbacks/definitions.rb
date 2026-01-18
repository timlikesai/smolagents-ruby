module Smolagents
  module Types
    module Callbacks
      # Hash-driven callback type definitions.
      #
      # Each entry maps an event name to its signature specification:
      # - required: Array of required argument names
      # - optional: Array of optional argument names
      # - types: Hash mapping argument names to type specifications
      #
      # Type specifications can be:
      # - A Class (e.g., Integer, String)
      # - A String for deferred resolution (e.g., "Types::ActionStep")
      # - An Array for union types (e.g., [Symbol, String])
      DEFINITIONS = {
        before_step: {
          required: [:step_number],
          optional: [],
          types: { step_number: Integer }
        },
        after_step: {
          required: [:step],
          optional: [:monitor],
          types: {
            step: "Types::ActionStep",
            monitor: ["Concerns::Monitorable::StepMonitor", NilClass]
          }
        },
        after_task: {
          required: [:result],
          optional: [],
          types: { result: "Types::RunResult" }
        },
        on_max_steps: {
          required: [:step_count],
          optional: [],
          types: { step_count: Integer }
        },
        after_monitor: {
          required: %i[step_name monitor],
          optional: [],
          types: {
            step_name: [Symbol, String],
            monitor: "Concerns::Monitorable::StepMonitor"
          }
        },
        on_step_error: {
          required: %i[step_name error monitor],
          optional: [],
          types: {
            step_name: [Symbol, String],
            error: StandardError,
            monitor: "Concerns::Monitorable::StepMonitor"
          }
        },
        on_tokens_tracked: {
          required: [:usage],
          optional: [],
          types: { usage: "Types::TokenUsage" }
        }
      }.freeze

      # Builds CallbackSignature objects from definitions.
      module SignatureBuilder
        module_function

        # Builds all signatures from DEFINITIONS.
        #
        # @return [Hash{Symbol => CallbackSignature}] frozen hash of signatures
        def build_all
          DEFINITIONS.transform_values { |spec| build_one(spec) }.freeze
        end

        # Builds a single signature from a specification.
        #
        # @param spec [Hash] the specification hash
        # @return [CallbackSignature] the built signature
        def build_one(spec)
          CallbackSignature.new(
            required_args: spec[:required],
            optional_args: spec[:optional],
            arg_types: spec[:types]
          )
        end
      end
    end
  end
end
