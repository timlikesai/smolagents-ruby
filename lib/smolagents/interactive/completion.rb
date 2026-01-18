module Smolagents
  module Interactive
    # Tab completion for IRB sessions.
    #
    # Provides contextual completions for the Smolagents DSL:
    # - Builder methods after `Smolagents.agent.`
    # - Tool names after `.tools(`
    # - Toolkit names after `.tools(`
    # - Persona names after `.as(` or `.persona(`
    # - Specialization names after `.with(`
    #
    # @example Enable completion
    #   Smolagents::Interactive::Completion.enable
    #
    # @example Available completions
    #   Smolagents.agent.<TAB>     # Shows: model, tools, as, with, planning...
    #   .tools(:<TAB>              # Shows: :search, :web, :visit_webpage...
    #   .as(:<TAB>                 # Shows: :researcher, :analyst...
    #   .with(:<TAB>               # Shows: :researcher, :data_analyst...
    module Completion
      # Builder method names available for completion.
      BUILDER_METHODS = %i[
        model tools as persona with planning memory instructions
        max_steps can_spawn evaluation on build
      ].freeze

      # Patterns for recognizing completion contexts.
      PATTERNS = {
        tools: /\.tools\(\s*:?(\w*)$/,
        persona: /\.(?:as|persona)\(\s*:?(\w*)$/,
        specialization: /\.with\(\s*:?(\w*)$/,
        builder: /(?:Smolagents\.agent)?\.(\w*)$/
      }.freeze

      class << self
        # Enable tab completion for IRB.
        #
        # @return [Boolean] true if completion was enabled, false if IRB unavailable
        # rubocop:disable Naming/PredicateMethod -- enable is an action, not a predicate
        def enable
          return false unless irb_available?

          register_completion_proc
          true
        end
        # rubocop:enable Naming/PredicateMethod

        # Check if IRB completion is available.
        # @return [Boolean]
        def irb_available?
          !!(defined?(IRB) && IRB.conf && defined?(IRB::InputCompletor))
        end

        # Generate completions for the given input.
        #
        # @param input [String] Current input line
        # @return [Array<String>] Matching completions
        def completions_for(input)
          match_tools(input) || match_persona(input) || match_specialization(input) ||
            match_builder(input) || []
        end

        private

        def match_tools(input)
          return unless (match = PATTERNS[:tools].match(input))

          tool_completions(match[1])
        end

        def match_persona(input)
          return unless (match = PATTERNS[:persona].match(input))

          persona_completions(match[1])
        end

        def match_specialization(input)
          return unless (match = PATTERNS[:specialization].match(input))

          specialization_completions(match[1])
        end

        def match_builder(input)
          return unless (match = PATTERNS[:builder].match(input))

          builder_method_completions(match[1])
        end

        def register_completion_proc
          original_proc = IRB::InputCompletor::CompletionProc

          IRB.conf[:COMPLETION_PROC] = lambda do |input|
            smolagents_completions = completions_for(input)
            smolagents_completions.any? ? smolagents_completions : original_proc.call(input)
          end
        end

        def tool_completions(prefix)
          all_tools = Toolkits.names + Tools.names.map(&:to_sym)
          filter_and_format(all_tools, prefix, symbol: true)
        end

        def persona_completions(prefix)
          filter_and_format(Personas.names, prefix, symbol: true)
        end

        def specialization_completions(prefix)
          filter_and_format(Specializations.names, prefix, symbol: true)
        end

        def builder_method_completions(prefix)
          filter_and_format(BUILDER_METHODS, prefix, symbol: false)
        end

        def filter_and_format(items, prefix, symbol:)
          prefix_str = prefix.to_s.downcase
          matches = items.select { |item| item.to_s.downcase.start_with?(prefix_str) }
          symbol ? matches.map { |m| ":#{m}" } : matches.map(&:to_s)
        end
      end
    end
  end
end
