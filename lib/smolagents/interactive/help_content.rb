module Smolagents
  module Interactive
    # Help text content constants.
    module HelpContent
      # Builder methods distinction - key concept for newcomers
      BUILDER_METHODS_HELP = <<~TEXT.freeze
        Three methods configure agent capabilities:

        .tools(:search)      Add toolkit (what agent CAN do)
        .as(:researcher)     Add persona (HOW agent behaves)
        .with(:researcher)   Convenience: tools + persona together

        The relationship:
          .with(:researcher) == .tools(:research).as(:researcher)
      TEXT

      BUILDER_TOOLS_HELP = <<~RUBY.freeze
        # .tools() adds toolkits (auto-expand to individual tools)
        .tools(:search)           # Search tools only
        .tools(:search, :web)     # Multiple toolkits
        .tools(MyCustomTool.new)  # Custom tool instances

        # Available toolkits:
        #   :search   - DuckDuckGo + Wikipedia
        #   :web      - Visit webpages
        #   :data     - Ruby interpreter
        #   :research - Search + web combined
      RUBY

      BUILDER_AS_HELP = <<~RUBY.freeze
        # .as() adds persona (behavior only, NO tools!)
        .tools(:search).as(:researcher)   # Must add tools separately

        # Available personas:
        #   :researcher    - Research and citation approach
        #   :fact_checker  - Verification methodology
        #   :analyst       - Data analysis approach
        #   :calculator    - Mathematical computation
        #   :scraper       - Web extraction approach
      RUBY

      BUILDER_WITH_HELP = <<~RUBY.freeze
        # .with() is convenience: adds tools + persona together
        .with(:researcher)    # Same as .tools(:research).as(:researcher)

        # Available specializations:
        #   :researcher    - Research tools + persona
        #   :fact_checker  - Fact-check tools + persona
        #   :data_analyst  - Data tools + analyst persona
        #   :calculator    - Ruby interpreter + calc persona
        #   :web_scraper   - Web tools + scraper persona
      RUBY

      BUILDER_COMBINING_HELP = <<~RUBY.freeze
        # Combine methods for customization
        Smolagents.agent
          .with(:researcher)              # Start with bundle
          .tools(:data)                   # Add extra tools
          .instructions("Be concise")     # Add custom instructions
          .model { m }
          .build
      RUBY

      QUICK_START = <<~RUBY.freeze
        # Create and run an agent
        result = Smolagents.agent
          .model { Smolagents::OpenAIModel.lm_studio("model-name") }
          .tools(:search)
          .run("Your task here")

        puts result.output
      RUBY

      LOCAL_SERVERS_HELP = <<~RUBY.freeze
        # LM Studio (port 1234)
        model = Smolagents::OpenAIModel.lm_studio("model-name")

        # Ollama (port 11434)
        model = Smolagents::OpenAIModel.ollama("model-name")

        # llama.cpp (port 8080)
        model = Smolagents::OpenAIModel.llama_cpp("model-name")
      RUBY

      CLOUD_PROVIDERS_HELP = <<~RUBY.freeze
        # OpenRouter (100+ models)
        model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")

        # Groq (fast inference)
        model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile")

        # Direct OpenAI
        model = Smolagents::OpenAIModel.new(model_id: "gpt-4-turbo")
      RUBY

      TOOLKITS_HELP = <<~RUBY.freeze
        .tools(:search)    # DuckDuckGo + Wikipedia
        .tools(:web)       # Visit webpages
        .tools(:data)      # Ruby interpreter
        .tools(:research)  # Search + web combined
      RUBY

      CUSTOM_TOOLS_HELP = <<~RUBY.freeze
        class WeatherTool < Smolagents::Tool
          self.tool_name = "weather"
          self.description = "Get weather for a city"
          self.inputs = { city: { type: "string", description: "City name" } }
          self.output_type = "string"

          def execute(city:)
            # Your implementation
          end
        end

        agent = Smolagents.agent
          .model { m }
          .tools(WeatherTool.new)
          .build
      RUBY

      ONESHOT_HELP = <<~RUBY.freeze
        result = Smolagents.agent
          .model { m }
          .tools(:search)
          .run("Find Ruby 4.0 features")
      RUBY

      REUSABLE_HELP = <<~RUBY.freeze
        agent = Smolagents.agent
          .model { m }
          .tools(:search)
          .build

        agent.run("Task 1")
        agent.run("Task 2")
      RUBY

      EVENTS_HELP = <<~RUBY.freeze
        result = Smolagents.agent
          .model { m }
          .on(:tool_call) { |e| puts "Calling: \#{e.tool_name}" }
          .on(:step_complete) { |e| puts "Step \#{e.step_number} done" }
          .run("Do something")
      RUBY

      SCAN_HELP = <<~RUBY.freeze
        # Full scan
        discovery = Smolagents::Discovery.scan

        # Check what's available
        puts discovery.summary

        # Get code examples
        discovery.code_examples.each { |ex| puts ex }
      RUBY

      ENDPOINTS_HELP = <<~RUBY.freeze
        # Scan additional servers
        discovery = Smolagents::Discovery.scan(
          custom_endpoints: [
            { provider: :llama_cpp, host: "gpu-server.local", port: 8080 },
            { provider: :llama_cpp, host: "api.example.com", port: 443, tls: true }
          ]
        )
      RUBY
    end
  end
end
