module Smolagents
  module Interactive
    # Generates contextual suggestions and examples based on available resources.
    #
    # Creates delightful, ready-to-run code examples that adapt to:
    # - Available models
    # - Configured search providers
    # - Rotating interesting questions
    #
    # Designed to delight both beginners and experienced Ruby developers.
    module Suggestions
      # Question bank - fun, innocuous questions that showcase the agent.
      # Mix of evergreen and timely topics.
      QUESTIONS = [
        # Programming & Ruby
        "What are the newest features in Ruby %<ruby_version>s?",
        "Find the most popular Ruby gems released recently",
        "What's new in Rails 8?",
        "Search for beginner-friendly Ruby tutorials",
        "What programming languages are trending in %<year>s?",

        # Fun facts & trivia
        "What's the current population of %<city>s?",
        "Find interesting facts about %<animal>s",
        "Who won the most recent Nobel Prize in %<nobel>s?",
        "What are some fun facts about %<city>s?",

        # Current events (safe topics)
        "What are the top stories on Hacker News right now?",
        "Find recent space exploration news",
        "What's happening in the world of open source software?",

        # Practical
        "Find the best-rated coffee shops in %<city>s",
        "What time zone is %<city>s in?",
        "Search for Ruby conferences in %<year>s"
      ].freeze

      # Data for question interpolation
      CITIES = %w[Tokyo London Paris Sydney Berlin Amsterdam Barcelona Seoul Singapore Melbourne Vienna Prague Lisbon
                  Dublin].freeze
      ANIMALS = ["octopus", "mantis shrimp", "axolotl", "tardigrade", "pangolin", "narwhal", "capybara", "red panda",
                 "slow loris"].freeze
      NOBEL_CATEGORIES = %w[Physics Chemistry Literature Peace Economics Medicine].freeze

      class << self
        # Generate a contextual suggestion based on available resources.
        #
        # @param discovery [Discovery::Result] Discovery scan results
        # @return [Suggestion, nil] A suggestion or nil if no models available
        def generate(discovery)
          model = pick_model(discovery)
          return nil unless model

          Suggestion.new(
            model:,
            question: pick_question,
            search_provider: current_search_provider
          )
        end

        # Get the currently configured search provider info.
        #
        # @return [Hash, nil] Provider info with :name and :url, or nil if default
        def current_search_provider
          provider = Smolagents.configuration.search_provider
          return nil if provider == :duckduckgo # Default, don't highlight

          url = case provider
                when :searxng then Smolagents.configuration.searxng_url
                end

          name = Config::SEARCH_PROVIDERS.find { |p| p == provider }&.to_s&.capitalize || provider.to_s

          { name:, provider:, url: }
        end

        private

        def pick_model(discovery)
          ready_models = discovery.all_models.select(&:ready?)
          return nil if ready_models.empty?

          # Prefer local models, then by name (shorter names often = better known models)
          ready_models.min_by do |m|
            score = 0
            score += 100 unless m.localhost? # Prefer local
            score += m.id.length # Prefer shorter/simpler names
            score
          end
        end

        def pick_question
          template = QUESTIONS.sample
          interpolate(template)
        end

        def interpolate(template)
          template
            .gsub("%<city>s", CITIES.sample)
            .gsub("%<animal>s", ANIMALS.sample)
            .gsub("%<nobel>s", NOBEL_CATEGORIES.sample)
            .gsub("%<year>s", Time.now.year.to_s)
            .gsub("%<ruby_version>s", RUBY_VERSION.split(".").first(2).join("."))
        end
      end

      # A generated suggestion with all components needed for a runnable example.
      Suggestion = Data.define(:model, :question, :search_provider) do
        # Generate the code example as a string.
        #
        # @return [String] Ready-to-run Ruby code
        def code
          <<~RUBY.chomp
            result = Smolagents.agent
              .model { #{model_code} }
              .tools(:search)
              .on(:step) { |e| puts "Step \#{e.step_number}: \#{e.action}" }
              .on(:tool) { |e| puts "  → \#{e.tool_name}: \#{e.result.to_s[0,80]}" }
              .run("#{question}")

            puts result.output
          RUBY
        end

        # @return [Boolean] True if using a non-default search provider
        def custom_search?
          !search_provider.nil?
        end

        # @return [String] Human-readable search provider description
        def search_description
          return "DuckDuckGo + Wikipedia" unless custom_search?

          case search_provider[:provider]
          when :searxng
            url = search_provider[:url]
            host = url ? URI.parse(url).host : "your instance"
            "SearXNG (#{host})"
          else
            search_provider[:name]
          end
        end

        private

        def model_code
          model.code_example
               .sub(/^model = /, "")
               .sub(/\s*#.*$/, "") # Remove trailing comments
               .strip
        end
      end
    end
  end
end
