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
          parts = [INTRO]

          # Tool documentation with clear formatting
          if tools&.any?
            tool_section = ["TOOLS AVAILABLE:"]
            tool_names = []

            tools.each do |tool_doc|
              formatted = format_tool(tool_doc)
              tool_section << formatted
              # Extract tool name for examples (from def line)
              def_line = tool_doc.lines.find { |l| l.strip.start_with?("def ") }
              tool_names << ::Regexp.last_match(1) if def_line =~ /def (\w+)\(/
            end

            parts << tool_section.join("\n\n")

            # Add relevant example based on tools
            example_added = false
            tool_names.each do |name|
              next unless (ex = tool_example(name))

              parts << "EXAMPLE with #{name}:\n#{ex}"
              example_added = true
              break
            end
            parts << DEFAULT_EXAMPLE unless example_added
          else
            parts << DEFAULT_EXAMPLE
          end

          # Team members (managed agents)
          if team&.any?
            team_section = ["TEAM MEMBERS (call like tools):"]
            team.each do |member|
              name = member.split(":").first.strip
              team_section << "- #{name}(task: \"description of what to do\")"
            end
            parts << team_section.join("\n")
          end

          # Authorized imports
          parts << "ALLOWED REQUIRES: #{authorized_imports.join(", ")}" if authorized_imports&.any?

          parts << RULES
          parts << custom if custom

          parts.compact.join("\n\n")
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
    end
  end
end
