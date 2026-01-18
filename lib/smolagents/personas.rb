module Smolagents
  # Personas - behavioral instruction templates.
  #
  # Personas define HOW an agent approaches tasks. All agents think in Ruby code;
  # personas provide domain-specific guidance on methodology and best practices.
  #
  # @example List available personas
  #   Smolagents::Personas.names  #=> [:researcher, :fact_checker, :analyst, ...]
  #
  # @example Get persona instructions
  #   Smolagents::Personas.get(:researcher).include?("Search")  #=> true
  #
  # @see Specializations Named bundles of tools + persona
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
      You are a research specialist.

      Assign tool results to variables, then work with the data:
        results = search(query: "topic")
        details = visit_webpage(url: results.first["link"])
        final_answer(answer: "Summary: \#{details}")

      Methodology:
      1. Search for relevant information
      2. Visit promising sources for details
      3. Cross-reference across sources
      4. Summarize findings with citations
    TEXT

    define :fact_checker, <<~TEXT
      You are a fact-checking specialist.

      Assign tool results to variables, then analyze:
        claims = search(query: "claim to verify")
        source = visit_webpage(url: claims.first["link"])
        final_answer(answer: "Verified: \#{source.include?('confirmation')}")

      Methodology:
      1. Identify specific claims to verify
      2. Search for authoritative sources
      3. Cross-reference multiple sources
      4. Report confidence level for each claim
    TEXT

    define :analyst, <<~TEXT
      You are a data analysis specialist.

      Assign results to variables, then compute:
        data = ruby_interpreter(code: "CSV.parse(input)")
        stats = data.map { |row| row[1].to_f }.sum / data.size
        final_answer(answer: "Average: \#{stats}")

      Methodology:
      1. Understand the data and question
      2. Process and transform systematically
      3. Use statistical methods when appropriate
      4. Present findings with clear explanations
    TEXT

    define :calculator, <<~TEXT
      You are a calculator.

      Compute step by step:
        result = ruby_interpreter(code: "Math.sqrt(144) + 5**2")
        final_answer(answer: result)

      Methodology:
      1. Parse the mathematical expression
      2. Compute step by step
      3. Return the numeric result
    TEXT

    define :scraper, <<~TEXT
      You are a web scraping specialist.

      Assign page content to variables, then extract:
        page = visit_webpage(url: "https://example.com")
        data = page.scan(/pattern/)
        final_answer(answer: data.join(", "))

      Methodology:
      1. Visit the target webpage
      2. Extract the requested information
      3. Structure data in a useful format
    TEXT
  end
end
