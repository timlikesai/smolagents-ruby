module Smolagents
  module Testing
    class ModelBenchmark
      # Test case definitions for model benchmark levels.
      #
      # Defines the 6 capability levels tested:
      #   1. Basic Response - Can the model respond at all?
      #   2. Format Compliance - Can it generate proper Ruby code blocks?
      #   3. Tool Calling - Can it call a single tool correctly?
      #   4. Multi-Step - Can it complete a 2-3 step task?
      #   5. Complex Reasoning - Can it handle multi-tool reasoning?
      #   6. Vision - Can it process images? (VLM only)
      module TestDefinitions
        LEVEL2_PROMPT = "Write Ruby code that prints \"hello world\". Put your code in a ```ruby code block.".freeze
        LEVEL4_TASK = <<~TASK.strip
          Solve this step by step:
          1. First, calculate 25 * 4 using the calculate tool
          2. Then, subtract 50 from that result using the calculate tool
          3. Return the final number with final_answer
        TASK
        LEVEL5_TASK = <<~TASK.strip
          Ruby 3.0 was released in 2020. If Ruby releases a new major version every 3 years,
          calculate when Ruby 4.0 will release (3.0 in 2020, so 4.0 = 2020 + 3 years = ?).
          Use the calculate tool to compute 2020 + 3, then return the year with final_answer.
        TASK

        # Get tests for a specific level.
        #
        # @param level [Integer] Test level (1-6)
        # @return [Array<Hash>] Array of test definitions
        def tests_for_level(level)
          case level
          when 1 then [level1_basic_response]
          when 2 then [level2_code_format]
          when 3 then [level3_tool_call]
          when 4 then [level4_multi_step]
          when 5 then [level5_reasoning]
          when 6 then [level6_vision]
          else []
          end
        end

        private

        def level1_basic_response
          { name: "basic_response", level: 1, type: :chat,
            prompt: "What is 2 + 2? Reply with just the number.",
            validator: ->(response) { response.to_s.include?("4") } }
        end

        def level2_code_format
          { name: "code_format", level: 2, type: :chat,
            prompt: LEVEL2_PROMPT, validator: method(:validate_code_format) }
        end

        def validate_code_format(response)
          text = response.to_s
          has_code = text.match?(/```(?:ruby)?\s*\n/i) || text.match?(/<code>/i)
          has_hello = text.match?(/puts.*hello.*world/im) || text.match?(/print.*hello.*world/im)
          has_code && has_hello
        end

        def level3_tool_call
          { name: "single_tool_call", level: 3, type: :agent, tools: [:calculator], max_steps: 5,
            task: "Calculate 15 * 7 using the calculate tool, then return the result with final_answer.",
            validator: ->(r) { r.success? && r.output.to_s.include?("105") } }
        end

        def level4_multi_step
          { name: "multi_step_task", level: 4, type: :agent, tools: [:calculator], max_steps: 8,
            task: LEVEL4_TASK, validator: ->(r) { r.success? && r.output.to_s.include?("50") } }
        end

        def level5_reasoning
          { name: "complex_reasoning", level: 5, type: :agent, tools: [:calculator], max_steps: 6,
            task: LEVEL5_TASK, validator: ->(r) { r.success? && r.output.to_s.include?("2023") } }
        end

        def level6_vision
          { name: "vision_test", level: 6, type: :vision,
            prompt: "What color is the Ruby logo? Describe what you see.",
            image_url: "https://www.ruby-lang.org/images/header-ruby-logo.png",
            validator: ->(response) { response.to_s.downcase.include?("red") } }
        end
      end
    end
  end
end
