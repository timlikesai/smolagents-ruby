module Smolagents
  module Specializations
    # Built-in specialization definitions.
    #
    # Each specialization is defined as a hash with:
    # - tools: Array of tool symbols
    # - instructions: Optional instruction string (references Personas)
    #
    # All agents think in Ruby code - specializations add tools and personas.
    #
    # @api private
    module BuiltIn
      DEFINITIONS = {
        data_analyst: {
          tools: [:ruby_interpreter],
          instructions: :analyst
        },

        researcher: {
          tools: %i[duckduckgo_search visit_webpage wikipedia_search],
          instructions: :researcher
        },

        fact_checker: {
          tools: %i[duckduckgo_search wikipedia_search visit_webpage],
          instructions: :fact_checker
        },

        calculator: {
          tools: [:ruby_interpreter],
          instructions: :calculator
        },

        web_scraper: {
          tools: [:visit_webpage],
          instructions: :scraper
        }
      }.freeze

      # Registers all built-in specializations with the registry.
      #
      # @param registry [Module] The Specializations registry module
      # @return [void]
      def self.register_all(registry)
        DEFINITIONS.each do |name, config|
          instructions = resolve_instructions(config[:instructions])
          registry.define(name, tools: config[:tools] || [], instructions:)
        end
      end

      # Resolves instruction references to actual text.
      #
      # @param ref [Symbol, String, nil] Persona name or literal instructions
      # @return [String, nil] The resolved instruction text
      def self.resolve_instructions(ref)
        return nil if ref.nil?
        return ref if ref.is_a?(String)

        Personas.get(ref)
      end
    end
  end
end
