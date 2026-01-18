module Smolagents
  module Types
    # Configuration for dynamic agent spawning at runtime.
    #
    # SpawnConfig controls what resources child agents can access when
    # spawned dynamically from parent agent code. It provides security
    # boundaries and resource limits for spawned agents.
    #
    # == Options
    #
    # - +:allowed_models+ - Models that spawned agents can use
    # - +:allowed_tools+ - Tools that spawned agents can access
    # - +:inherit_scope+ - How much parent context to pass to children
    # - +:max_children+ - Maximum number of agents that can be spawned
    #
    # @example Creating a spawn config
    #   config = SpawnConfig.create(
    #     allow: [:test_model, :small_model],
    #     tools: [:final_answer, :search],
    #     inherit: :observations,
    #     max_children: 5
    #   )
    #
    # @example Checking permissions
    #   config.model_allowed?(:test_model)  # => true
    #   config.tool_allowed?(:search)       # => true
    #
    # @see Runtime::Spawn Dynamic agent spawning
    SpawnConfig = Data.define(:allowed_models, :allowed_tools, :inherit_scope, :max_children) do
      # Creates a spawn config with the given options.
      #
      # @param allow [Array<Symbol>] Allowed model identifiers (default: [])
      # @param tools [Array<Symbol>] Allowed tool names (default: [:final_answer])
      # @param inherit [Symbol] Context scope to inherit (default: :task_only)
      # @param max_children [Integer] Maximum spawned agents (default: 3)
      # @return [SpawnConfig] New spawn config
      #
      # @example Permissive config
      #   SpawnConfig.create(
      #     allow: [:gpt4, :claude],
      #     tools: [:search, :web, :final_answer],
      #     max_children: 10
      #   )
      def self.create(allow: [], tools: [:final_answer], inherit: :task_only, max_children: 3)
        scope = inherit.is_a?(ContextScope) ? inherit : ContextScope.create(inherit)
        new(
          allowed_models: Array(allow).map(&:to_sym).freeze,
          allowed_tools: Array(tools).map(&:to_sym).freeze,
          inherit_scope: scope,
          max_children:
        )
      end

      # Creates a disabled spawn config that prevents all spawning.
      #
      # @return [SpawnConfig] Config with max_children: 0
      def self.disabled
        new(allowed_models: [].freeze, allowed_tools: [].freeze, inherit_scope: ContextScope.create(:task_only),
            max_children: 0)
      end

      # Checks if a model is allowed for spawned agents.
      #
      # @param model [Symbol, String] Model identifier
      # @return [Boolean] True if model is allowed
      def model_allowed?(model)
        return true if allowed_models.empty?

        allowed_models.include?(model.to_sym)
      end

      # Checks if a tool is allowed for spawned agents.
      #
      # @param tool [Symbol, String] Tool name
      # @return [Boolean] True if tool is allowed
      def tool_allowed?(tool)
        allowed_tools.include?(tool.to_sym)
      end

      # Checks if spawning is enabled.
      #
      # @return [Boolean] True if max_children > 0
      def enabled? = max_children.positive?

      # Checks if spawning is disabled.
      #
      # @return [Boolean] True if max_children == 0
      def disabled? = max_children.zero?
    end
  end
end
