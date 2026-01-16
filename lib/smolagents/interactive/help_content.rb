module Smolagents
  module Interactive
    # Help text content constants.
    module HelpContent
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
