module Smolagents
  module Utilities
    # Dynamic prompt generation for agent system prompts.
    #
    # All agents use Ruby method call syntax for tools - it's natural for LLMs
    # and our flexible input handling accepts variations gracefully.
    #
    # @example Generate an agent prompt
    #   prompt = Prompts.agent(tools: [search, calculator])
    #
    # @example Generate a code agent prompt
    #   prompt = Prompts.code(tools: [interpreter], custom: "Show your work")
    module Prompts
      # Base agent prompt - Ruby method calls for tools
      module Agent
        INTRO = <<~PROMPT.freeze
          You solve tasks by calling tools. Tools are Ruby methods.

          Call one tool at a time:
          tool_name(arg: "value")

          After the tool runs, you'll see the result. Then call another tool or finish.
          To finish, call final_answer with your result:
          final_answer(answer: "your answer here")
        PROMPT

        DEFAULT_EXAMPLE = <<~PROMPT.freeze
          Example:
          Task: "What is the capital of France?"
          search(query: "capital of France")
          Observation: Paris is the capital and largest city of France...
          final_answer(answer: "Paris")
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Call one tool at a time
          2. Use argument names from tool descriptions
          3. Finish with final_answer(answer: "result")
        PROMPT

        class << self
          def generate(tools:, team: nil, custom: nil)
            [INTRO, tools_section(tools), DEFAULT_EXAMPLE,
             team_section(team), RULES, custom].compact.join("\n\n")
          end

          def tools_section(tools)
            return nil unless tools&.any?

            formatted = tools.map { |t| format_tool(t) }
            ["TOOLS:", *formatted].join("\n")
          end

          def format_tool(tool_doc)
            # tool_doc format: "tool_name(arg: desc) - description"
            "- #{tool_doc}"
          end

          def team_section(team)
            return nil unless team&.any?

            members = team.map { |m| "- #{m.split(":").first.strip}(task: \"what to do\")" }
            ["TEAM (call like tools):", *members].join("\n")
          end
        end
      end

      # Code agent prompt - extends base with code block format
      #
      # Adapted from Python smolagents with Ruby idioms and extensive examples.
      module CodeAgent
        INTRO = <<~PROMPT.freeze
          You are an expert assistant who solves tasks using Ruby code.
          Respond with a ```ruby code block. Use comments for reasoning.

          ```ruby
          # Your reasoning as comments
          result = tool_name(arg: value)
          final_answer(answer: result)
          ```

          IMPORTANT:
          - Write ONLY Ruby code in the code block (comments are fine)
          - End with final_answer(answer: result) when done
          - Tool results support arithmetic: result * 2, result + 10
          - Use puts(budget) to see step budget (remaining steps)
          - When low on steps, call final_answer immediately
          - STOP after closing ``` marks
        PROMPT

        # Examples showing Ruby-only format with comments for reasoning
        EXAMPLES = <<~PROMPT.freeze
          EXAMPLES:
          ---
          Task: "What is 25 times 4, then double it?"

          ```ruby
          # Calculate step by step - tool results support arithmetic
          result = calculate(expression: "25 * 4")
          final_result = result * 2
          final_answer(answer: final_result)
          ```

          ---
          Task: "Find the population of Tokyo and divide it by 1000."

          ```ruby
          # Search for current data, then calculate
          data = web_search(query: "Tokyo population 2026")
          puts data  # See what we got
          ```
          Observation: Tokyo has approximately 14 million people.

          ```ruby
          # Now do the division
          population = 14_000_000
          final_answer(answer: population / 1000)
          ```

          ---
          Task: "What is the current weather in Paris?"

          ```ruby
          # Search and return directly
          weather = web_search(query: "current weather Paris")
          final_answer(answer: weather)
          ```
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Output ONLY a ```ruby code block (use # comments for reasoning)
          2. Use keyword arguments: tool_name(arg: value)
          3. Tool results support arithmetic: result * 2, result + 10
          4. End with final_answer(answer: result)
          5. DO NOT use variable names in strings passed to tools:
             WRONG: calculate(expression: "x + 10")  # x is just text!
             RIGHT: x + 10                           # Direct arithmetic works!
          6. STOP after closing ``` - do not continue
        PROMPT

        class << self
          def generate(tools:, team: nil, authorized_imports: nil, custom: nil)
            [INTRO, tools_section(tools), example_for_tools(tools),
             team_section(team),
             (authorized_imports&.any? ? "ALLOWED REQUIRES: #{authorized_imports.join(", ")}" : nil),
             RULES, custom].compact.join("\n\n")
          end

          def tools_section(tools)
            return nil unless tools&.any?

            formatted = tools.map { |doc| format_tool(doc) }
            ["TOOLS AVAILABLE:", *formatted].join("\n\n")
          end

          def format_tool(tool_doc)
            # Tool doc format: "tool_name: description\n  Takes inputs: {...}\n  Returns: type"
            lines = tool_doc.split("\n")
            name_desc = lines.first.split(": ", 2)
            name = name_desc.first
            description = name_desc.last

            # Extract args from "Takes inputs: {arg: {type: ...}}"
            inputs_line = lines.find { |l| l.include?("Takes inputs:") }
            args = inputs_line&.scan(/(\w+): \{type:/)&.flatten || []

            call_example = args.empty? ? "#{name}()" : "#{name}(#{args.first}: \"...\")"
            "- #{name}(#{args.map { |a| "#{a}:" }.join(", ")}): #{description}\n  Example: #{call_example}"
          end

          def example_for_tools(_tools)
            # Use comprehensive examples showing multiple patterns
            EXAMPLES
          end

          def team_section(team)
            return nil unless team&.any?

            members = team.map { |m| "- #{m.split(":").first.strip}(task: \"what to do\")" }
            ["TEAM MEMBERS (call like tools):", *members].join("\n")
          end
        end
      end

      # Convenience methods
      def self.agent(...) = Agent.generate(...)
      def self.code(...) = CodeAgent.generate(...)

      # Legacy aliases
      def self.tool(...) = Agent.generate(...)
      def self.code_agent(...) = CodeAgent.generate(...)

      # Generates capabilities prompt from agent configuration.
      #
      # @param tools [Hash<String, Tool>] Available tools keyed by name
      # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents
      # @param agent_type [Symbol] :code or :tool (both use Ruby syntax)
      # @return [String] Prompt addendum with usage examples
      def self.generate_capabilities(tools:, managed_agents: nil, agent_type: :tool)
        CapabilitiesGenerator.generate(tools:, managed_agents:, agent_type:)
      end

      # Generates capabilities prompts from agent configuration.
      module CapabilitiesGenerator
        TYPE_EXAMPLES = {
          "number" => 42.5,
          "boolean" => true,
          "array" => %w[item1 item2],
          "object" => { key: "value" }
        }.freeze

        class << self
          def generate(tools:, managed_agents: nil, agent_type: :tool)
            parts = []
            parts << tool_capabilities(tools, agent_type) if tools&.any?
            parts << agent_capabilities(managed_agents) if managed_agents&.any?
            parts.compact.join("\n\n")
          end

          private

          def tool_capabilities(tools, agent_type)
            user_tools = tools.except("final_answer")
            return nil if user_tools.empty?

            examples = user_tools.values.take(3).map { |tool| tool_example(tool, agent_type) }
            return nil if examples.empty?

            "TOOL USAGE:\n#{examples.join("\n\n")}"
          end

          def tool_example(tool, agent_type)
            args = generate_example_args(tool.inputs)
            call = "#{tool.name}(#{format_ruby_args(args)})"

            if agent_type == :code
              <<~EXAMPLE.strip
                # #{tool.description}
                result = #{call}
              EXAMPLE
            else
              <<~EXAMPLE.strip
                # #{tool.description}
                #{call}
              EXAMPLE
            end
          end

          def generate_example_args(inputs)
            inputs.transform_values do |spec|
              example_value_for_type(spec[:type], spec[:description])
            end
          end

          def example_value_for_type(type, description)
            case type
            when "string" then infer_string_example(description)
            when "integer" then infer_integer_example(description)
            else TYPE_EXAMPLES.fetch(type, "...")
            end
          end

          def infer_string_example(description)
            desc = description.to_s.downcase
            return "your search query" if desc.include?("query") || desc.include?("search")
            return "https://example.com" if desc.include?("url")
            return "/path/to/file" if desc.include?("path") || desc.include?("file")
            return "2 + 2" if desc.include?("expression")

            "..."
          end

          def infer_integer_example(description)
            desc = description.to_s.downcase
            return 10 if desc.include?("limit") || desc.include?("max")
            return 1 if desc.include?("page")

            5
          end

          def format_ruby_args(args)
            args.map do |key, value|
              formatted = value.is_a?(String) ? "\"#{value}\"" : value.inspect
              "#{key}: #{formatted}"
            end.join(", ")
          end

          def agent_capabilities(managed_agents)
            return nil if managed_agents.nil? || managed_agents.empty?

            examples = managed_agents.values.take(2).map { |agent| agent_example(agent) }
            return nil if examples.empty?

            <<~SECTION.strip
              SUB-AGENTS:
              #{examples.join("\n\n")}
            SECTION
          end

          def agent_example(agent)
            <<~EXAMPLE.strip
              # #{agent.description}
              #{agent.name}(task: "describe what you need")
            EXAMPLE
          end
        end
      end
    end
  end
end
