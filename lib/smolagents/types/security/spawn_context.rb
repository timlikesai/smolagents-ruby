module Smolagents
  module Security
    # Context for spawn validation tracking current execution state.
    #
    # SpawnContext captures the state needed to validate spawn requests:
    # depth in the spawn hierarchy, remaining step budget, and parent tools.
    #
    # @example Creating a context
    #   context = SpawnContext.create(
    #     depth: 1,
    #     remaining_steps: 15,
    #     parent_tools: [:search, :web]
    #   )
    #
    # @example Descending to child context
    #   child_context = context.descend(steps_allocated: 5)
    #   child_context.depth      #=> 2
    #   child_context.remaining_steps  #=> 5
    #
    # @see SpawnPolicy For policy validation
    SpawnContext = Data.define(:depth, :remaining_steps, :parent_tools, :spawn_path, :remaining_tokens) do
      def self.create(depth: 0, remaining_steps: 100, parent_tools: [], spawn_path: [], remaining_tokens: nil)
        new(depth:, remaining_steps:, parent_tools: Array(parent_tools).map(&:to_sym).freeze,
            spawn_path: Array(spawn_path).freeze, remaining_tokens:)
      end

      def self.root(max_steps:, tools:, agent_name: "root", token_budget: nil)
        create(depth: 0, remaining_steps: max_steps, parent_tools: tools,
               spawn_path: [agent_name], remaining_tokens: token_budget)
      end

      def descend(steps_allocated:, child_tools: nil, agent_name: "child", tokens_allocated: nil)
        effective_tools = child_tools || parent_tools
        effective_tokens = tokens_allocated || remaining_tokens
        self.class.new(
          depth: depth + 1,
          remaining_steps: steps_allocated,
          parent_tools: effective_tools.map(&:to_sym).freeze,
          spawn_path: (spawn_path + [agent_name]).freeze,
          remaining_tokens: effective_tokens
        )
      end

      def root? = depth.zero?
      def parent_name = spawn_path[-2]
      def current_name = spawn_path.last
      def path_string = spawn_path.join(" > ")

      def deconstruct_keys(_)
        { depth:, remaining_steps:, parent_tools:, spawn_path:, remaining_tokens: }
      end
    end
  end
end
