module Smolagents
  # Personas - behavioral instruction templates.
  #
  # Personas define HOW an agent should approach tasks.
  # Apply them with `.as(:persona_name)`.
  #
  # @example Using a persona
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .tools(:search)
  #     .as(:researcher)
  #     .model { @model }
  #     .build
  #
  # @example Combining persona with custom instructions
  #   @model = Smolagents::Testing::MockModel.new
  #   @model.queue_final_answer("done")
  #   agent = Smolagents.agent
  #     .as(:researcher)
  #     .instructions("Also focus on recent sources.")
  #     .model { @model }
  #     .build
  #
  # @example Direct access
  #   Smolagents::Personas.researcher.include?("research specialist")  #=> true
  #   Smolagents::Personas.names.include?(:researcher)  #=> true
  module Personas
    class << self
      # Research-focused behavior
      def researcher
        <<~TEXT
          You are a research specialist. Your approach:
          1. Search for relevant information on the topic
          2. Gather detailed facts from promising sources
          3. Cross-reference information across sources
          4. Summarize findings with citations
        TEXT
      end

      # Fact verification behavior
      def fact_checker
        <<~TEXT
          You are a fact-checking specialist. Your approach:
          1. Identify claims to verify
          2. Search for authoritative sources
          3. Cross-reference multiple sources
          4. Report confidence level for each claim
        TEXT
      end

      # Data analysis behavior (best with code mode)
      def analyst
        <<~TEXT
          You are a data analysis specialist. Your approach:
          1. Understand the data and the question being asked
          2. Process, analyze, or transform the data systematically
          3. Use statistical methods when appropriate
          4. Present findings with clear explanations
        TEXT
      end

      # Mathematical computation behavior (best with code mode)
      def calculator
        <<~TEXT
          You are a calculator. Your approach:
          1. Parse the mathematical expression or problem
          2. Compute the answer step by step
          3. Return the numeric result
        TEXT
      end

      # Web scraping behavior
      def scraper
        <<~TEXT
          You are a web scraping specialist. Your approach:
          1. Visit the target webpage
          2. Extract the requested information
          3. Structure the data in a useful format
        TEXT
      end

      # All available persona names
      def names = %i[researcher fact_checker analyst calculator scraper]

      # Get a persona by name, or nil if not found
      def get(name)
        return unless names.include?(name.to_sym)

        public_send(name)
      end
    end
  end
end
