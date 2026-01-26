module Smolagents
  module Builders
    # Inline tool definition DSL for AgentBuilder.
    #
    # Allows defining tools directly in the builder without separate classes.
    module InlineToolConcern
      # Define an inline tool with a block - no class required.
      #
      # For simple tools, define them directly in the builder instead of
      # creating a separate class. The block receives keyword arguments
      # matching the input types.
      #
      # @param name [Symbol, String] Tool name
      # @param description [String] What the tool does
      # @param inject_models [Array<Symbol>] Model purposes to inject as keyword args
      # @param inputs [Hash{Symbol => Class}] Input name => type (String, Integer, etc.)
      # @param block [Proc] The tool implementation
      # @return [AgentBuilder]
      #
      # @example Simple inline tool
      #   builder = Smolagents.agent.tool(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }
      #   builder.config[:tool_instances].size
      #   #=> 1
      #
      # @example Multiple inputs
      #   builder = Smolagents.agent.tool(:add, "Add numbers", a: Integer, b: Integer) { |a:, b:| a + b }
      #   builder.config[:tool_instances].first.name.to_sym
      #   #=> :add
      #
      # @example Tool with model injection
      #   builder = Smolagents.agent
      #     .model(:vision) { vision_model }
      #     .tool(:analyze, "Analyze image", inject_models: [:vision], url: String) do |url:, vision:|
      #       vision.generate([{ role: :user, content: "Analyze #{url}" }])
      #     end
      #
      # @see InlineTool The underlying type
      # @see #tools For adding pre-defined tools
      def tool(name, description, inject_models: nil, **inputs, &block)
        check_frozen!
        raise ArgumentError, "Block required for inline tool" unless block

        inline = Tools::InlineTool.create(name, description, inject_models:, **inputs, &block)
        with_config(tool_instances: configuration[:tool_instances] + [inline])
      end
    end
  end
end
