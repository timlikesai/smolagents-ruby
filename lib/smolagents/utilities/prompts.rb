module Smolagents
  module Utilities
    # Dynamic prompt generation for agent system prompts.
    #
    # Optimized for small models with clear structure:
    # - Explicit tool call examples
    # - Clear separators between sections
    # - Concise rules
    # - Structured output format
    #
    # @example Generate a code agent prompt
    #   prompt = Prompts.code_agent(
    #     tools: [calculator, search],
    #     team: [researcher_agent],
    #     custom: "Focus on accuracy."
    #   )
    module Prompts
      module CodeAgent
        INTRO = <<~PROMPT.freeze
          You solve tasks by writing Ruby code. You have tools available as Ruby methods.

          FORMAT: Always respond with Thought then Code:

          Thought: <your reasoning>
          ```ruby
          <your code here>
          ```

          After your code runs, you'll see the output. Then write more code or finish.
          To finish: call final_answer(answer: <result>)
        PROMPT

        # Generate tool-specific examples based on available tools
        def self.tool_example(tool_name)
          case tool_name
          when "calculate"
            <<~EXAMPLE
              Task: "What is 25 times 4?"
              Thought: I'll calculate this and return the answer.
              ```ruby
              result = calculate(expression: "25 * 4")
              final_answer(answer: result)
              ```
            EXAMPLE
          when "searxng_search", "web_search"
            <<~EXAMPLE
              Task: "What is the capital of France?"
              Thought: I'll search for this and return the answer.
              ```ruby
              results = #{tool_name}(query: "capital of France")
              final_answer(answer: results)
              ```
            EXAMPLE
          end
        end

        DEFAULT_EXAMPLE = <<~PROMPT.freeze
          Example:
          Task: "What is 10 + 5?"
          Thought: Simple math, I'll calculate and return.
          ```ruby
          result = 10 + 5
          final_answer(answer: result)
          ```
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Always write Thought, then ```ruby code block
          2. Call tools with keyword args: tool_name(arg: value)
          3. End with final_answer(answer: <your_result>)
          4. You can call multiple tools and final_answer in one code block
        PROMPT

        def self.format_tool(tool_doc)
          lines = tool_doc.strip.split("\n")

          # Extract tool name from def line (last line in YARD format)
          def_line = lines.find { |l| l.start_with?("def ") }
          name_match = def_line&.match(/def (\w+)\(/)
          tool_name = name_match ? name_match[1] : "tool"

          # Extract params from @param lines for call example
          param_lines = lines.select { |l| l.include?("@param") }
          call_args = param_lines.filter_map do |line|
            next unless line =~ /@param (\w+) \[(\w+)\]/

            param_name = ::Regexp.last_match(1)
            param_type = ::Regexp.last_match(2)
            case param_type
            when "String" then "#{param_name}: \"...\""
            when "Integer", "Float" then "#{param_name}: 123"
            else "#{param_name}: value"
            end
          end.join(", ")

          "--- #{tool_name} ---\n#{tool_doc}\nCall: #{tool_name}(#{call_args})"
        end

        def self.generate(tools:, team: nil, authorized_imports: nil, custom: nil)
          [INTRO, tools_section(tools), team_section(team),
           (authorized_imports&.any? ? "ALLOWED REQUIRES: #{authorized_imports.join(", ")}" : nil),
           RULES, custom].compact.join("\n\n")
        end

        def self.tools_section(tools)
          return DEFAULT_EXAMPLE unless tools&.any?

          tool_names = []
          formatted_tools = tools.map do |doc|
            def_line = doc.lines.find { |l| l.strip.start_with?("def ") }
            tool_names << ::Regexp.last_match(1) if def_line =~ /def (\w+)\(/
            format_tool(doc)
          end

          example = tool_names.find { |n| tool_example(n) }&.then { |n| "EXAMPLE with #{n}:\n#{tool_example(n)}" }
          ["TOOLS AVAILABLE:", *formatted_tools, example || DEFAULT_EXAMPLE].compact.join("\n\n")
        end

        def self.team_section(team)
          return nil unless team&.any?

          ["TEAM MEMBERS (call like tools):", *team.map { |m| "- #{m.split(":").first.strip}(task: \"description of what to do\")" }].join("\n")
        end
      end

      module ToolCallingAgent
        INTRO = <<~PROMPT.freeze
          You solve tasks by calling tools. Respond with a JSON tool call.

          FORMAT:
          {"name": "tool_name", "arguments": {"arg1": "value1"}}

          After the tool runs, you'll see the result. Then call another tool or finish.
          To finish: {"name": "final_answer", "arguments": {"answer": "your result"}}
        PROMPT

        DEFAULT_EXAMPLE = <<~PROMPT.freeze
          Example:
          Task: "What is 15 * 7?"
          {"name": "calculate", "arguments": {"expression": "15 * 7"}}
          Observation: 105
          {"name": "final_answer", "arguments": {"answer": "105"}}
        PROMPT

        RULES = <<~PROMPT.freeze
          RULES:
          1. Respond ONLY with JSON tool call
          2. Use exact argument names from tool descriptions
          3. End with final_answer tool
        PROMPT

        def self.generate(tools:, team: nil, custom: nil)
          parts = [INTRO]

          # Tool documentation
          if tools&.any?
            tool_section = ["TOOLS:"]
            tools.each { |t| tool_section << "- #{t}" }
            parts << tool_section.join("\n")
          end

          parts << DEFAULT_EXAMPLE

          # Team members
          if team&.any?
            team_section = ["TEAM MEMBERS:"]
            team.each { |m| team_section << "- #{m}" }
            parts << team_section.join("\n")
          end

          parts << RULES
          parts << custom if custom

          parts.compact.join("\n\n")
        end
      end

      # Backward-compatible preset interface
      module Presets
        def self.code_agent(tools:, team: nil, authorized_imports: nil, custom: nil)
          CodeAgent.generate(tools:, team:, authorized_imports:, custom:)
        end

        def self.tool_calling(tools:, team: nil, custom: nil)
          ToolCallingAgent.generate(tools:, team:, custom:)
        end
      end

      # Convenience method for building prompts
      def self.code_agent(...) = Presets.code_agent(...)
      def self.tool_calling(...) = Presets.tool_calling(...)

      # Generates a capabilities prompt addendum based on agent configuration.
      #
      # Introspects tools and managed_agents to generate contextual examples
      # that teach models how to use the agent's specific capabilities.
      #
      # @param tools [Hash<String, Tool>] Available tools keyed by name
      # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents keyed by name
      # @param agent_type [Symbol] :code or :tool_calling
      # @return [String] Prompt addendum with usage examples
      #
      # @example Generate capabilities for a code agent
      #   prompt = Prompts.generate_capabilities(
      #     tools: { "search" => search_tool },
      #     managed_agents: { "researcher" => researcher_agent },
      #     agent_type: :code
      #   )
      def self.generate_capabilities(tools:, managed_agents: nil, agent_type: :code)
        CapabilitiesGenerator.generate(tools:, managed_agents:, agent_type:)
      end

      # Generates capabilities prompts from agent configuration.
      module CapabilitiesGenerator
        class << self
          # Generates a complete capabilities prompt.
          #
          # @param tools [Hash<String, Tool>] Available tools
          # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents
          # @param agent_type [Symbol] :code or :tool_calling
          # @return [String] Combined capabilities prompt
          def generate(tools:, managed_agents: nil, agent_type: :code)
            parts = []
            parts << tool_capabilities(tools, agent_type) if tools&.any?
            parts << agent_capabilities(managed_agents, agent_type) if managed_agents&.any?
            parts.compact.join("\n\n")
          end

          private

          # Generates tool usage examples based on actual tool signatures.
          #
          # @param tools [Hash<String, Tool>] Available tools
          # @param agent_type [Symbol] :code or :tool_calling
          # @return [String, nil] Tool capabilities section
          def tool_capabilities(tools, agent_type)
            # Skip final_answer - it's documented separately
            user_tools = tools.except("final_answer")
            return nil if user_tools.empty?

            examples = user_tools.values.take(3).map { |tool| tool_example(tool, agent_type) }
            return nil if examples.empty?

            header = agent_type == :code ? "TOOL USAGE PATTERNS:" : "TOOL CALL PATTERNS:"
            "#{header}\n#{examples.join("\n\n")}"
          end

          # Generates a usage example for a single tool.
          #
          # @param tool [Tool] The tool to document
          # @param agent_type [Symbol] :code or :tool_calling
          # @return [String] Example usage
          def tool_example(tool, agent_type)
            case agent_type
            when :code
              code_tool_example(tool)
            else
              json_tool_example(tool)
            end
          end

          # Generates Ruby code example for a tool.
          #
          # @param tool [Tool] The tool
          # @return [String] Ruby code example
          def code_tool_example(tool)
            args = generate_example_args(tool.inputs)
            call = "#{tool.name}(#{format_ruby_args(args)})"

            <<~EXAMPLE.strip
              # #{tool.description}
              result = #{call}
            EXAMPLE
          end

          # Generates JSON tool call example.
          #
          # @param tool [Tool] The tool
          # @return [String] JSON example
          def json_tool_example(tool)
            args = generate_example_args(tool.inputs)
            json = { name: tool.name, arguments: args }

            <<~EXAMPLE.strip
              # #{tool.description}
              #{JSON.generate(json)}
            EXAMPLE
          end

          # Generates example argument values based on input specifications.
          #
          # @param inputs [Hash] Tool input specifications
          # @return [Hash] Example arguments
          def generate_example_args(inputs)
            inputs.transform_values do |spec|
              example_value_for_type(spec[:type], spec[:description])
            end
          end

          # Generates an example value for a given type.
          #
          # @param type [String] The input type
          # @param description [String] Input description for context
          # @return [Object] Example value
          def example_value_for_type(type, description)
            case type
            when "string"
              infer_string_example(description)
            when "integer"
              infer_integer_example(description)
            when "number"
              42.5
            when "boolean"
              true
            when "array"
              %w[item1 item2]
            when "object"
              { key: "value" }
            else
              "..."
            end
          end

          # Infers a reasonable string example from description.
          #
          # @param description [String] Input description
          # @return [String] Example string
          def infer_string_example(description)
            desc_lower = description.to_s.downcase
            if desc_lower.include?("query") || desc_lower.include?("search")
              "your search query"
            elsif desc_lower.include?("url")
              "https://example.com"
            elsif desc_lower.include?("path") || desc_lower.include?("file")
              "/path/to/file"
            elsif desc_lower.include?("expression")
              "2 + 2"
            else
              "..."
            end
          end

          # Infers a reasonable integer example from description.
          #
          # @param description [String] Input description
          # @return [Integer] Example integer
          def infer_integer_example(description)
            desc_lower = description.to_s.downcase
            if desc_lower.include?("limit") || desc_lower.include?("max")
              10
            elsif desc_lower.include?("page")
              1
            else
              5
            end
          end

          # Formats arguments as Ruby keyword arguments.
          #
          # @param args [Hash] Arguments to format
          # @return [String] Formatted Ruby kwargs
          def format_ruby_args(args)
            args.map do |key, value|
              formatted_value = value.is_a?(String) ? "\"#{value}\"" : value.inspect
              "#{key}: #{formatted_value}"
            end.join(", ")
          end

          # Generates managed agent (sub-agent) usage examples.
          #
          # @param managed_agents [Hash<String, ManagedAgentTool>] Sub-agents
          # @param agent_type [Symbol] :code or :tool_calling
          # @return [String, nil] Agent capabilities section
          def agent_capabilities(managed_agents, agent_type)
            return nil if managed_agents.nil? || managed_agents.empty?

            examples = managed_agents.values.take(2).map { |agent| agent_example(agent, agent_type) }
            return nil if examples.empty?

            <<~SECTION.strip
              SUB-AGENT DELEGATION:
              You can delegate tasks to specialized sub-agents:

              #{examples.join("\n\n")}

              Sub-agents run independently and return their results. Use them for specialized tasks.
            SECTION
          end

          # Generates a usage example for a managed agent.
          #
          # @param agent [ManagedAgentTool] The managed agent tool
          # @param agent_type [Symbol] :code or :tool_calling
          # @return [String] Example usage
          def agent_example(agent, agent_type)
            case agent_type
            when :code
              <<~EXAMPLE.strip
                # #{agent.description}
                result = #{agent.name}(task: "describe what you need the agent to do")
              EXAMPLE
            else
              json = { name: agent.name, arguments: { task: "describe what you need the agent to do" } }
              <<~EXAMPLE.strip
                # #{agent.description}
                #{JSON.generate(json)}
              EXAMPLE
            end
          end
        end
      end
    end
  end
end
