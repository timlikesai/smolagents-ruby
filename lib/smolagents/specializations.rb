module Smolagents
  # Registry for convenience agent specializations.
  #
  # Specializations are convenience bundles that combine:
  # - Tools (from Toolkits)
  # - Instructions (from Personas)
  # - Mode requirements (`:code` when needed)
  #
  # For finer control, use the atomic building blocks directly:
  # - `Toolkits` - Tool groupings (SEARCH, WEB, DATA, RESEARCH)
  # - `Personas` - Behavioral instructions (RESEARCHER, ANALYST, etc.)
  #
  # @example Using specializations (convenient)
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("Research complete")
  #   agent = Smolagents.agent
  #     .with(:researcher)
  #     .model { @model }
  #     .build
  #
  # @example Using atoms directly (explicit)
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .tools(*Smolagents::Toolkits.research)
  #     .as(:researcher)
  #     .model { @model }
  #     .build
  #
  # @example Data analyst (enables code mode)
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("Analysis complete")
  #   agent = Smolagents.agent.with(:data_analyst).model { @model }.build
  #   agent.is_a?(Smolagents::Agents::Agent)  #=> true
  #
  # @see Toolkits Tool groupings
  # @see Personas Behavioral instructions
  # @see Builders::AgentBuilder#with The DSL method
  module Specializations
    @registry = {}

    class << self
      # Register a specialization.
      #
      # @param name [Symbol] Unique identifier for the specialization
      # @param tools [Array<Symbol>] Tool names to include
      # @param instructions [String, nil] Instructions to add to system prompt
      # @param requires [Symbol, nil] Capability requirement (:code for code execution)
      # @return [Types::Specialization] The registered specialization
      def register(name, tools: [], instructions: nil, requires: nil)
        @registry[name.to_sym] = Types::Specialization.create(
          name, tools:, instructions:, requires:
        )
      end

      # Look up a specialization by name.
      #
      # @param name [Symbol, String] Specialization name
      # @return [Types::Specialization, nil] The specialization or nil
      def get(name) = @registry[name.to_sym]

      # List all registered specialization names.
      #
      # @return [Array<Symbol>] Available specialization names
      def names = @registry.keys

      # Get all registered specializations.
      #
      # @return [Array<Types::Specialization>]
      def all = @registry.values
    end

    # Built-in specializations

    # Code execution capability - enables Ruby code generation and execution.
    # This is a capability flag; other specializations may require it.
    register :code

    # Data analyst - statistical analysis and data processing.
    # Uses code execution for Ruby-based data manipulation.
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

    # Researcher - web search and information synthesis.
    # Gathers facts from multiple sources and summarizes findings.
    register :researcher,
             tools: %i[duckduckgo_search visit_webpage wikipedia_search],
             instructions: <<~TEXT
               You are a research specialist. Your approach:
               1. Search for relevant information on the topic
               2. Gather detailed facts from promising sources
               3. Cross-reference information across sources
               4. Summarize findings with citations
             TEXT

    # Fact checker - verifies claims against authoritative sources.
    # Cross-references multiple sources and reports confidence levels.
    register :fact_checker,
             tools: %i[duckduckgo_search wikipedia_search visit_webpage],
             instructions: <<~TEXT
               You are a fact-checking specialist. Your approach:
               1. Identify claims to verify
               2. Search for authoritative sources
               3. Cross-reference multiple sources
               4. Report confidence level for each claim
             TEXT

    # Calculator - mathematical computations.
    # Focused on numeric calculations and expressions.
    register :calculator,
             tools: [:ruby_interpreter],
             instructions: <<~TEXT,
               You are a calculator. Your approach:
               1. Parse the mathematical expression or problem
               2. Write Ruby code to compute the answer
               3. Return the numeric result
             TEXT
             requires: :code

    # Web scraper - extracts structured data from web pages.
    # Visits URLs and extracts specific information.
    register :web_scraper,
             tools: [:visit_webpage],
             instructions: <<~TEXT
               You are a web scraping specialist. Your approach:
               1. Visit the target webpage
               2. Extract the requested information
               3. Structure the data in a useful format
             TEXT
  end
end
