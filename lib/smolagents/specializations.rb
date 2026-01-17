module Smolagents
  # Registry for convenience agent specializations.
  #
  # Specializations are convenience bundles that combine tools, instructions,
  # and mode requirements into a single named entity. Use them with `.with(:name)`.
  #
  # == Key Distinction
  #
  # - *Toolkits* add tools only (what the agent can use)
  # - *Personas* add instructions only (how the agent behaves)
  # - *Specializations* add both (convenience bundles)
  #
  # == Built-in Specializations
  #
  # [+:code+]
  #   Code execution capability flag. Enables Ruby code generation and execution.
  #
  # [+:data_analyst+]
  #   Statistical analysis and data processing. Requires code mode.
  #   Tools: ruby_interpreter
  #
  # [+:researcher+]
  #   Web search and information synthesis. Gathers facts and summarizes.
  #   Tools: duckduckgo_search, visit_webpage, wikipedia_search
  #
  # [+:fact_checker+]
  #   Verifies claims against authoritative sources with confidence levels.
  #   Tools: duckduckgo_search, wikipedia_search, visit_webpage
  #
  # [+:calculator+]
  #   Mathematical computations. Requires code mode.
  #   Tools: ruby_interpreter
  #
  # [+:web_scraper+]
  #   Extracts structured data from web pages.
  #   Tools: visit_webpage
  #
  # @example List all available specialization names
  #   Smolagents::Specializations.names.include?(:researcher)  #=> true
  #   Smolagents::Specializations.names.include?(:data_analyst)  #=> true
  #
  # @example Look up a specialization
  #   spec = Smolagents::Specializations.get(:researcher)
  #   spec.nil?  #=> false
  #
  # @example Unknown specialization returns nil
  #   Smolagents::Specializations.get(:unknown)  #=> nil
  #
  # @example Using specializations with agents (usage pattern, requires model)
  #   # Specializations bundle tools + instructions
  #   # agent = Smolagents.agent
  #   #   .with(:researcher)     # Adds search tools + researcher instructions
  #   #   .model { my_model }
  #   #   .build
  #
  # @example Equivalent explicit configuration (usage pattern, requires model)
  #   # Same as above, but explicit:
  #   # agent = Smolagents.agent
  #   #   .tools(:duckduckgo_search, :visit_webpage, :wikipedia_search)
  #   #   .as(:researcher)
  #   #   .model { my_model }
  #   #   .build
  #
  # @see Toolkits Tool groupings (what the agent can use)
  # @see Personas Behavioral instructions (how the agent behaves)
  # @see Builders::AgentBuilder#with The DSL method for using specializations
  # @see Smolagents.specialization Registering custom specializations
  module Specializations
    @registry = {}

    class << self
      # Registers a new specialization.
      #
      # Creates a specialization that bundles tools, instructions, and optional
      # capability requirements into a single named entity.
      #
      # @param name [Symbol] Unique identifier for the specialization
      # @param tools [Array<Symbol>] Tool names to include
      # @param instructions [String, nil] Instructions to add to system prompt
      # @param requires [Symbol, nil] Capability requirement (:code for code execution)
      # @return [Types::Specialization] The registered specialization
      #
      # @example Register a basic specialization
      #   Smolagents::Specializations.register(:my_spec, tools: [:search])
      #   Smolagents::Specializations.names.include?(:my_spec)  #=> true
      def register(name, tools: [], instructions: nil, requires: nil)
        @registry[name.to_sym] = Types::Specialization.create(
          name, tools:, instructions:, requires:
        )
      end

      # Looks up a specialization by name.
      #
      # @param name [Symbol, String] Specialization name
      # @return [Types::Specialization, nil] The specialization or nil if not found
      #
      # @example Valid specialization lookup
      #   Smolagents::Specializations.get(:researcher).nil?  #=> false
      #
      # @example Invalid name returns nil
      #   Smolagents::Specializations.get(:nonexistent)  #=> nil
      def get(name) = @registry[name.to_sym]

      # Returns all registered specialization names.
      #
      # @return [Array<Symbol>] Available specialization names
      #
      # @example List specialization names
      #   Smolagents::Specializations.names.include?(:researcher)  #=> true
      def names = @registry.keys

      # Returns all registered specializations.
      #
      # @return [Array<Types::Specialization>] All specialization objects
      #
      # @example Get all specializations
      #   Smolagents::Specializations.all.size >= 5  #=> true
      def all = @registry.values
    end

    # ============================================================
    # Built-in Specializations
    # ============================================================

    # @!group Built-in Specializations

    # Code execution capability flag.
    #
    # Enables Ruby code generation and execution. Other specializations
    # that need code execution (like :data_analyst, :calculator) require
    # this capability.
    register :code

    # Data analyst specialization.
    #
    # Statistical analysis and data processing specialist. Uses Ruby code
    # execution for data manipulation, analysis, and statistical methods.
    #
    # Tools: ruby_interpreter
    # Requires: :code
    register :data_analyst,
             tools: [:ruby_interpreter],
             instructions: <<~TEXT,
               You are a data analysis specialist. Your approach:
               1. Understand the data and the question being asked
               2. Write Ruby code to process, analyze, or transform the data
               3. Use statistical methods when appropriate (mean, median, std dev)
               4. Present findings with clear explanations
             TEXT
             requires: :code

    # Researcher specialization.
    #
    # Web search and information synthesis specialist. Searches multiple
    # sources, gathers detailed facts, cross-references information,
    # and summarizes findings with citations.
    #
    # Tools: duckduckgo_search, visit_webpage, wikipedia_search
    register :researcher,
             tools: %i[duckduckgo_search visit_webpage wikipedia_search],
             instructions: <<~TEXT
               You are a research specialist. Your approach:
               1. Search for relevant information on the topic
               2. Gather detailed facts from promising sources
               3. Cross-reference information across sources
               4. Summarize findings with citations
             TEXT

    # Fact checker specialization.
    #
    # Verifies claims against authoritative sources. Identifies claims,
    # searches for evidence, cross-references multiple sources, and
    # reports confidence levels for each verified claim.
    #
    # Tools: duckduckgo_search, wikipedia_search, visit_webpage
    register :fact_checker,
             tools: %i[duckduckgo_search wikipedia_search visit_webpage],
             instructions: <<~TEXT
               You are a fact-checking specialist. Your approach:
               1. Identify claims to verify
               2. Search for authoritative sources
               3. Cross-reference multiple sources
               4. Report confidence level for each claim
             TEXT

    # Calculator specialization.
    #
    # Mathematical computation specialist. Parses expressions and problems,
    # writes Ruby code to compute answers, and returns numeric results.
    #
    # Tools: ruby_interpreter
    # Requires: :code
    register :calculator,
             tools: [:ruby_interpreter],
             instructions: <<~TEXT,
               You are a calculator. Your approach:
               1. Parse the mathematical expression or problem
               2. Write Ruby code to compute the answer
               3. Return the numeric result
             TEXT
             requires: :code

    # Web scraper specialization.
    #
    # Extracts structured data from web pages. Visits target URLs,
    # extracts requested information, and structures the data in
    # a useful format.
    #
    # Tools: visit_webpage
    register :web_scraper,
             tools: [:visit_webpage],
             instructions: <<~TEXT
               You are a web scraping specialist. Your approach:
               1. Visit the target webpage
               2. Extract the requested information
               3. Structure the data in a useful format
             TEXT

    # @!endgroup
  end
end
