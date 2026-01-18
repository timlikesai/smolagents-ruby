module Smolagents
  # Personas - behavioral instruction templates.
  #
  # Personas define HOW an agent should approach tasks. They provide
  # behavioral instructions without adding tools. Use them with `.as(:name)`.
  #
  # @example List available personas
  #   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, :calculator, :scraper]
  #
  # @example Get persona instructions
  #   Smolagents::Personas.get(:researcher).include?("research")  #=> true
  #
  # @see Toolkits Tool groupings (what the agent can use)
  # @see Specializations Pre-built toolkit + persona combinations
  module Personas
    @registry = {}

    class << self
      # Defines a persona with the given name and instructions.
      # @api private
      def define(name, instructions)
        @registry[name.to_sym] = instructions.freeze
        define_singleton_method(name) { @registry[name.to_sym] }
      end

      # Returns all available persona names.
      # @return [Array<Symbol>]
      def names = @registry.keys

      # Looks up a persona by name.
      # @param name [Symbol, String]
      # @return [String, nil]
      def get(name) = @registry[name.to_sym]
    end

    # ============================================================
    # Built-in Personas
    # ============================================================

    define :researcher, <<~TEXT
      You are a research specialist. Your approach:
      1. Search for relevant information on the topic
      2. Gather detailed facts from promising sources
      3. Cross-reference information across sources
      4. Summarize findings with citations
    TEXT

    define :fact_checker, <<~TEXT
      You are a fact-checking specialist. Your approach:
      1. Identify claims to verify
      2. Search for authoritative sources
      3. Cross-reference multiple sources
      4. Report confidence level for each claim
    TEXT

    define :analyst, <<~TEXT
      You are a data analysis specialist. Your approach:
      1. Understand the data and the question being asked
      2. Process, analyze, or transform the data systematically
      3. Use statistical methods when appropriate
      4. Present findings with clear explanations
    TEXT

    define :calculator, <<~TEXT
      You are a calculator. Your approach:
      1. Parse the mathematical expression or problem
      2. Compute the answer step by step
      3. Return the numeric result
    TEXT

    define :scraper, <<~TEXT
      You are a web scraping specialist. Your approach:
      1. Visit the target webpage
      2. Extract the requested information
      3. Structure the data in a useful format
    TEXT
  end
end
