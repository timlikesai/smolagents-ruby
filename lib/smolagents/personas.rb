module Smolagents
  # Personas - behavioral instruction templates.
  #
  # Personas define HOW an agent should approach tasks. They provide
  # behavioral instructions without adding tools. Use them with `.as(:name)`.
  #
  # == Key Distinction
  #
  # - *Personas* add behavioral instructions only (no tools)
  # - *Toolkits* add tools only (no instructions)
  # - *Specializations* add both (convenience bundles)
  #
  # == Available Personas
  #
  # [+:researcher+]
  #   Research specialist: searches, gathers facts, cross-references, summarizes.
  #
  # [+:fact_checker+]
  #   Fact verification: identifies claims, finds sources, reports confidence.
  #
  # [+:analyst+]
  #   Data analysis: processes data, uses statistics, presents findings.
  #   Best used with code mode.
  #
  # [+:calculator+]
  #   Mathematical computation: parses expressions, computes results.
  #   Best used with code mode.
  #
  # [+:scraper+]
  #   Web scraping: visits pages, extracts information, structures data.
  #
  # @example List all available persona names
  #   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, :calculator, :scraper]
  #
  # @example Check researcher persona content
  #   Smolagents::Personas.researcher.include?("research specialist")  #=> true
  #
  # @example Check fact_checker persona content
  #   Smolagents::Personas.fact_checker.include?("fact-checking")  #=> true
  #
  # @example Get persona by name (returns nil for unknown)
  #   Smolagents::Personas.get(:researcher).nil?  #=> false
  #   Smolagents::Personas.get(:unknown)  #=> nil
  #
  # @example Using personas with agents (usage pattern, requires model)
  #   # Personas add instructions, not tools
  #   # agent = Smolagents.agent
  #   #   .tools(:search)        # Add tools separately
  #   #   .as(:researcher)       # Add persona instructions
  #   #   .model { my_model }
  #   #   .build
  #
  # @see Toolkits Tool groupings (what the agent can use)
  # @see Specializations Pre-built toolkit + persona combinations
  # @see Builders::AgentBuilder#as Using personas in agent builder
  module Personas
    class << self
      # Returns instructions for research-focused behavior.
      #
      # The researcher persona guides agents to search for information,
      # gather facts from multiple sources, cross-reference findings,
      # and summarize with citations.
      #
      # @return [String] Research specialist instructions
      #
      # @example Researcher persona content
      #   Smolagents::Personas.researcher.include?("research specialist")  #=> true
      def researcher
        <<~TEXT
          You are a research specialist. Your approach:
          1. Search for relevant information on the topic
          2. Gather detailed facts from promising sources
          3. Cross-reference information across sources
          4. Summarize findings with citations
        TEXT
      end

      # Returns instructions for fact verification behavior.
      #
      # The fact_checker persona guides agents to identify claims,
      # search for authoritative sources, cross-reference multiple
      # sources, and report confidence levels.
      #
      # @return [String] Fact-checking specialist instructions
      #
      # @example Fact checker persona content
      #   Smolagents::Personas.fact_checker.include?("fact-checking")  #=> true
      def fact_checker
        <<~TEXT
          You are a fact-checking specialist. Your approach:
          1. Identify claims to verify
          2. Search for authoritative sources
          3. Cross-reference multiple sources
          4. Report confidence level for each claim
        TEXT
      end

      # Returns instructions for data analysis behavior.
      #
      # The analyst persona guides agents to understand data,
      # process and analyze it systematically, use statistical
      # methods, and present findings clearly.
      #
      # Best used with code mode enabled for Ruby-based analysis.
      #
      # @return [String] Data analysis specialist instructions
      #
      # @example Analyst persona content
      #   Smolagents::Personas.analyst.include?("data analysis")  #=> true
      def analyst
        <<~TEXT
          You are a data analysis specialist. Your approach:
          1. Understand the data and the question being asked
          2. Process, analyze, or transform the data systematically
          3. Use statistical methods when appropriate
          4. Present findings with clear explanations
        TEXT
      end

      # Returns instructions for mathematical computation behavior.
      #
      # The calculator persona guides agents to parse expressions,
      # compute answers step-by-step, and return numeric results.
      #
      # Best used with code mode enabled for Ruby-based computation.
      #
      # @return [String] Calculator instructions
      #
      # @example Calculator persona content
      #   Smolagents::Personas.calculator.include?("calculator")  #=> true
      def calculator
        <<~TEXT
          You are a calculator. Your approach:
          1. Parse the mathematical expression or problem
          2. Compute the answer step by step
          3. Return the numeric result
        TEXT
      end

      # Returns instructions for web scraping behavior.
      #
      # The scraper persona guides agents to visit webpages,
      # extract requested information, and structure the data.
      #
      # @return [String] Web scraping specialist instructions
      #
      # @example Scraper persona content
      #   Smolagents::Personas.scraper.include?("web scraping")  #=> true
      def scraper
        <<~TEXT
          You are a web scraping specialist. Your approach:
          1. Visit the target webpage
          2. Extract the requested information
          3. Structure the data in a useful format
        TEXT
      end

      # Returns all available persona names.
      #
      # @return [Array<Symbol>] Names of all registered personas
      #
      # @example Available personas
      #   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, :calculator, :scraper]
      def names = %i[researcher fact_checker analyst calculator scraper]

      # Looks up a persona by name.
      #
      # @param name [Symbol, String] Persona name to look up
      # @return [String, nil] Persona instructions, or nil if not found
      #
      # @example Valid persona lookup
      #   Smolagents::Personas.get(:researcher).nil?  #=> false
      #
      # @example Invalid persona returns nil
      #   Smolagents::Personas.get(:invalid)  #=> nil
      def get(name)
        return unless names.include?(name.to_sym)

        public_send(name)
      end
    end
  end
end
