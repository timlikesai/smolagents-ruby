module Smolagents
  module Builders
    # Specialization and persona DSL methods for AgentBuilder.
    #
    # Handles .with(:researcher) and .as(:researcher) methods.
    module SpecializationConcern
      # Add specialization (tools + persona bundle).
      #
      # @param names [Array<Symbol>] Specialization names
      # @return [AgentBuilder]
      #
      # @example
      #   .with(:researcher)     # adds research tools + researcher persona
      #   .with(:data_analyst)   # adds data tools + analyst persona
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

      # Apply a persona (behavioral instructions).
      #
      # @param name [Symbol] Persona name from Personas module
      # @return [AgentBuilder]
      #
      # @example
      #   Smolagents.agent.as(:researcher)
      def as(name)
        check_frozen!
        persona_text = Personas.get(name)
        raise ArgumentError, "Unknown persona: #{name}. Available: #{Personas.names.join(", ")}" unless persona_text

        instructions(persona_text)
      end

      private

      def collect_specializations(names)
        result = { tools: [], instructions: [] }
        names.each { |name| process_specialization_name(name, result) }
        result
      end

      def process_specialization_name(name, result)
        spec = Specializations.get(name)
        raise_unknown_specialization!(name) unless spec

        result[:tools].concat(spec.tools)
        result[:instructions] << spec.instructions if spec.instructions
      end

      def raise_unknown_specialization!(name)
        raise ArgumentError,
              "Unknown specialization: #{name}. Available: #{Specializations.names.join(", ")}"
      end

      def build_with_specializations(collected)
        updated_instructions = merge_instructions(collected[:instructions])
        self.class.new(
          configuration: configuration.merge(
            tool_names: (configuration[:tool_names] + collected[:tools]).uniq,
            custom_instructions: updated_instructions
          )
        )
      end

      def merge_instructions(new_instructions)
        merged = [configuration[:custom_instructions], *new_instructions].compact.join("\n\n")
        merged.empty? ? nil : merged
      end
    end
  end
end
