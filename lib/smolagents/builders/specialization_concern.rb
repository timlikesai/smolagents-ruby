module Smolagents
  module Builders
    # Specialization and persona DSL methods for AgentBuilder.
    #
    # Provides two methods for configuring agent behavior:
    #
    # [+.with(:name)+]
    #   Adds a *specialization* - a convenience bundle that includes both
    #   tools AND behavioral instructions. Use for quick setup.
    #
    # [+.as(:name)+]
    #   Applies a *persona* - behavioral instructions ONLY.
    #   Does NOT add any tools. Use when you want to control tools separately.
    #
    # == Key Distinction
    #
    #   .with(:researcher)  - Adds research tools + researcher behavior
    #   .as(:researcher)    - Adds researcher behavior only (no tools!)
    #
    # == Equivalence
    #
    #   .with(:researcher) == .tools(:research).as(:researcher)
    #
    # @example Using specialization (tools + persona)
    #   builder = Smolagents.agent.with(:researcher)
    #   builder.config[:tool_names].size > 0
    #   #=> true
    #
    # @example Using persona only
    #   builder = Smolagents.agent.as(:researcher)
    #   builder.config[:custom_instructions].nil?
    #   #=> false
    #
    # @see Specializations Available specializations
    # @see Personas Available personas
    # @see Toolkits Available toolkits
    module SpecializationConcern
      # Adds a specialization (tools + persona bundle).
      #
      # Specializations are convenience bundles that add both tools AND
      # behavioral instructions in a single call. Use for quick agent setup.
      #
      # For finer control, use +.tools+ and +.as+ separately.
      #
      # @param names [Array<Symbol>] Specialization names to apply
      # @return [AgentBuilder] New builder with specialization applied
      #
      # @example Adding a specialization
      #   builder = Smolagents.agent.with(:researcher)
      #   builder.config[:tool_names].size > 0
      #   #=> true
      #
      # @example Multiple specializations
      #   builder = Smolagents.agent.with(:researcher, :fact_checker)
      #   builder.config[:tool_names].size > 0
      #   #=> true
      #
      # @see #as For adding persona only (no tools)
      # @see Specializations.names For available specializations
      def with(*names)
        check_frozen!
        names = names.flatten.map(&:to_sym)
        return self if names.empty?

        # :code is accepted but ignored - all agents write code now
        names = names.reject { |n| n == :code }
        return self if names.empty?

        collected = collect_specializations(names)
        build_with_specializations(collected)
      end

      # Applies a persona (behavioral instructions ONLY).
      #
      # Personas define HOW the agent should approach tasks. They add
      # instructions to the system prompt but do NOT add any tools.
      #
      # Use +.as+ when you want to control tools separately from behavior.
      # For convenience (tools + behavior together), use +.with+ instead.
      #
      # @param name [Symbol] Persona name from Personas module
      # @return [AgentBuilder] New builder with persona applied
      #
      # @example Apply researcher behavior (no tools added)
      #   builder = Smolagents.agent.as(:researcher)
      #   builder.config[:custom_instructions].nil?
      #   #=> false
      #
      # @example Persona adds only final_answer (required by all agents)
      #   builder = Smolagents.agent.as(:researcher)
      #   builder.config[:tool_names]
      #   #=> [:final_answer]
      #
      # @see #with For adding tools + persona together
      # @see #persona Alias for this method
      # @see Personas.names For available personas
      def as(name)
        check_frozen!
        persona_text = Personas.get(name)
        raise ArgumentError, "Unknown persona: #{name}. Available: #{Personas.names.join(", ")}" unless persona_text

        instructions(persona_text)
      end

      # Alias for +.as+ method.
      #
      # Some users find +.persona(:researcher)+ more intuitive than +.as(:researcher)+.
      # Both methods work identically.
      #
      # @param name [Symbol] Persona name from Personas module
      # @return [AgentBuilder] New builder with persona applied
      #
      # @example Apply researcher behavior
      #   builder = Smolagents.agent.persona(:researcher)
      #   builder.config[:custom_instructions].nil?
      #   #=> false
      #
      # @see #as The primary method this aliases
      # @see Personas.names For available personas
      alias persona as

      private

      # Collect tools and instructions from specialization names.
      # @param names [Array<Symbol>] Specialization names
      # @return [Hash] {tools: [], instructions: []} hash
      def collect_specializations(names)
        result = { tools: [], instructions: [] }
        names.each { |name| process_specialization_name(name, result) }
        result
      end

      # Process a single specialization name into tools and instructions.
      # @param name [Symbol] Specialization name
      # @param result [Hash] Accumulator for tools and instructions
      # @return [void]
      def process_specialization_name(name, result)
        spec = Specializations.get(name)
        raise_unknown_specialization!(name) unless spec

        result[:tools].concat(spec.tools)
        result[:instructions] << spec.instructions if spec.instructions
      end

      # Raise error for unknown specialization.
      # @param name [Symbol] Specialization name
      # @return [void]
      # @raise [ArgumentError]
      def raise_unknown_specialization!(name)
        raise ArgumentError,
              "Unknown specialization: #{name}. Available: #{Specializations.names.join(", ")}"
      end

      # Build a new builder with specializations applied.
      # @param collected [Hash] Collected tools and instructions
      # @return [AgentBuilder]
      def build_with_specializations(collected)
        updated_instructions = merge_instructions(collected[:instructions])
        self.class.new(
          configuration: configuration.merge(
            tool_names: (configuration[:tool_names] + collected[:tools]).uniq,
            custom_instructions: updated_instructions
          )
        )
      end

      # Merge new instructions with existing ones.
      # @param new_instructions [Array<String>] New instruction strings
      # @return [String, nil] Merged instructions or nil if empty
      def merge_instructions(new_instructions)
        merged = [configuration[:custom_instructions], *new_instructions].compact.join("\n\n")
        merged.empty? ? nil : merged
      end
    end
  end
end
