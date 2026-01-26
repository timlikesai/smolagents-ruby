module Smolagents
  module Security
    # Result of spawn policy validation.
    #
    # Contains the outcome of a spawn policy validation check, including
    # whether the spawn is allowed and any violations that occurred.
    #
    # @example Checking validation result
    #   result = policy.validate(context, requested_tools: [:search])
    #   if result.allowed?
    #     proceed_with_spawn
    #   else
    #     puts result.violations.map(&:to_s).join("\n")
    #   end
    #
    # @see SpawnPolicy For policy validation
    # @see SpawnViolation For individual violations
    SpawnValidation = Data.define(:allowed, :violations) do
      # @return [Boolean] True if spawn is allowed
      def allowed? = allowed

      # @return [Boolean] True if spawn is denied
      def denied? = !allowed

      # @return [String] Formatted violation messages
      def to_error_message
        return nil if allowed?

        "Spawn denied:\n#{violations.map { |v| "  - #{v}" }.join("\n")}"
      end

      # Pattern matching support.
      def deconstruct_keys(_) = { allowed:, violations: }
    end
  end
end
