module Smolagents
  module Specializations
    # Built-in specialization definitions.
    #
    # Each specialization is defined as a hash with:
    # - tools: Array of tool symbols
    # - instructions: Optional instruction string (references Personas)
    # - requires: Optional capability requirement (:code)
    #
    # @api private
    module BuiltIn
      DEFINITIONS = {
        code: {},

        data_analyst: {
          tools: [:ruby_interpreter],
          instructions: :analyst,
          requires: :code
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
          instructions: :calculator,
          requires: :code
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
          registry.define(name,
                          tools: config[:tools] || [],
                          instructions:,
                          requires: config[:requires])
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
