# Lazy Evaluation Integration Tests
#
# Tests that ToolFuture lazy evaluation works correctly in agent code.
# Verifies conditional patterns, method delegation, and batch resolution.
#
# These tests verify fixes from the toolfuture-comprehensive-implementation plan.

RSpec.describe "Lazy Evaluation Integration", :integration do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  describe "conditional patterns with ToolFuture" do
    let(:string_tool) do
      Smolagents::Tools.create(
        "get_string",
        description: "Returns a string value",
        inputs: {},
        output_type: "string"
      ) { "hello world" }
    end

    let(:nil_tool) do
      Smolagents::Tools.create(
        "get_nil",
        description: "Returns nil",
        inputs: {},
        output_type: "any"
      ) { nil }
    end

    let(:array_tool) do
      Smolagents::Tools.create(
        "get_array",
        description: "Returns an array",
        inputs: {},
        output_type: "array"
      ) { [1, 2, 3] }
    end

    let(:empty_array_tool) do
      Smolagents::Tools.create(
        "get_empty_array",
        description: "Returns empty array",
        inputs: {},
        output_type: "array"
      ) { [] }
    end

    let(:hash_tool) do
      Smolagents::Tools.create(
        "get_hash",
        description: "Returns a hash",
        inputs: {},
        output_type: "object"
      ) { { name: "Alice", age: 30 } }
    end

    describe "is_a? checks" do
      it "handles is_a?(String) check after tool call" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_string()
          if result.is_a?(String)
            final_answer(answer: "It's a string: \#{result}")
          else
            final_answer(answer: "Not a string")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(string_tool)
                          .build

        result = agent.run("Check the type")

        expect(result).to be_success
        expect(result.output).to eq("It's a string: hello world")
      end

      it "handles is_a?(Array) check after tool call" do
        mock_model.queue_code_action(<<~RUBY)
          data = get_array()
          if data.is_a?(Array)
            final_answer(answer: "Array with \#{data.length} items")
          else
            final_answer(answer: "Not an array")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(array_tool)
                          .build

        result = agent.run("Check if array")

        expect(result).to be_success
        expect(result.output).to eq("Array with 3 items")
      end

      it "handles is_a?(Hash) check after tool call" do
        mock_model.queue_code_action(<<~RUBY)
          data = get_hash()
          if data.is_a?(Hash)
            final_answer(answer: "Hash with name: \#{data[:name]}")
          else
            final_answer(answer: "Not a hash")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(hash_tool)
                          .build

        result = agent.run("Check hash type")

        expect(result).to be_success
        expect(result.output).to eq("Hash with name: Alice")
      end
    end

    describe "nil? checks" do
      it "handles nil? check on actual nil result" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_nil()
          if result.nil?
            final_answer(answer: "Got nil")
          else
            final_answer(answer: "Got value: \#{result}")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(nil_tool)
                          .build

        result = agent.run("Check for nil")

        expect(result).to be_success
        expect(result.output).to eq("Got nil")
      end

      it "handles nil? check on non-nil result" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_string()
          if result.nil?
            final_answer(answer: "Got nil")
          else
            final_answer(answer: "Got: \#{result}")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(string_tool)
                          .build

        result = agent.run("Check for nil")

        expect(result).to be_success
        expect(result.output).to eq("Got: hello world")
      end
    end

    describe "empty? checks" do
      it "handles empty? on empty array" do
        mock_model.queue_code_action(<<~RUBY)
          data = get_empty_array()
          if data.empty?
            final_answer(answer: "Array is empty")
          else
            final_answer(answer: "Array has items")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(empty_array_tool)
                          .build

        result = agent.run("Check if empty")

        expect(result).to be_success
        expect(result.output).to eq("Array is empty")
      end

      it "handles empty? on non-empty array" do
        mock_model.queue_code_action(<<~RUBY)
          data = get_array()
          if data.empty?
            final_answer(answer: "Array is empty")
          else
            final_answer(answer: "Array has \#{data.length} items")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(array_tool)
                          .build

        result = agent.run("Check if empty")

        expect(result).to be_success
        expect(result.output).to eq("Array has 3 items")
      end
    end

    describe "boolean negation patterns" do
      it "handles unless result pattern" do
        mock_model.queue_code_action(<<~RUBY)
          data = get_array()
          unless data.empty?
            final_answer(answer: "Has data: \#{data.first}")
          else
            final_answer(answer: "No data")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(array_tool)
                          .build

        result = agent.run("Check data")

        expect(result).to be_success
        expect(result.output).to eq("Has data: 1")
      end

      it "handles !result.nil? pattern" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_string()
          if !result.nil?
            final_answer(answer: "Got result: \#{result}")
          else
            final_answer(answer: "No result")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(string_tool)
                          .build

        result = agent.run("Check result")

        expect(result).to be_success
        expect(result.output).to eq("Got result: hello world")
      end
    end

    describe "comparison operators" do
      it "handles == comparison" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_string()
          if result == "hello world"
            final_answer(answer: "Match!")
          else
            final_answer(answer: "No match")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(string_tool)
                          .build

        result = agent.run("Compare strings")

        expect(result).to be_success
        expect(result.output).to eq("Match!")
      end

      it "handles != comparison" do
        mock_model.queue_code_action(<<~RUBY)
          result = get_string()
          if result != "goodbye"
            final_answer(answer: "Different: \#{result}")
          else
            final_answer(answer: "Same")
          end
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(string_tool)
                          .build

        result = agent.run("Compare strings")

        expect(result).to be_success
        expect(result.output).to eq("Different: hello world")
      end
    end
  end

  describe "method delegation via method_missing" do
    let(:string_tool) do
      Smolagents::Tools.create(
        "get_string",
        description: "Returns a string value",
        inputs: {},
        output_type: "string"
      ) { "hello world" }
    end

    let(:array_tool) do
      Smolagents::Tools.create(
        "get_array",
        description: "Returns an array",
        inputs: {},
        output_type: "array"
      ) { [1, 2, 3] }
    end

    it "delegates string methods" do
      mock_model.queue_code_action(<<~RUBY)
        result = get_string()
        upper = result.upcase
        final_answer(answer: upper)
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(string_tool)
                        .build

      result = agent.run("Uppercase it")

      expect(result).to be_success
      expect(result.output).to eq("HELLO WORLD")
    end

    it "delegates array methods" do
      mock_model.queue_code_action(<<~RUBY)
        data = get_array()
        final_answer(answer: data.sum.to_s)
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(array_tool)
                        .build

      result = agent.run("Sum array")

      expect(result).to be_success
      expect(result.output).to eq("6")
    end

    it "chains multiple method calls" do
      mock_model.queue_code_action(<<~RUBY)
        result = get_string()
        processed = result.split(" ").map(&:capitalize).join("-")
        final_answer(answer: processed)
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(string_tool)
                        .build

      result = agent.run("Process string")

      expect(result).to be_success
      expect(result.output).to eq("Hello-World")
    end
  end

  describe "batch resolution with dependent futures" do
    let(:tool_a) do
      Smolagents::Tools.create(
        "get_value_a",
        description: "Returns value A",
        inputs: {},
        output_type: "integer"
      ) { 10 }
    end

    let(:tool_b) do
      Smolagents::Tools.create(
        "multiply",
        description: "Multiply a number",
        inputs: { value: { type: "integer", description: "Value to multiply" } },
        output_type: "integer"
      ) { |value:| value * 2 }
    end

    it "resolves dependent futures in correct order" do
      mock_model.queue_code_action(<<~RUBY)
        a = get_value_a()
        b = multiply(value: a)
        final_answer(answer: b.to_s)
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(tool_a, tool_b)
                        .build

      result = agent.run("Chain calls")

      expect(result).to be_success
      expect(result.output).to eq("20")
    end
  end

  describe "final_answer with future values" do
    let(:string_tool) do
      Smolagents::Tools.create(
        "get_data",
        description: "Returns data",
        inputs: {},
        output_type: "string"
      ) { "the data" }
    end

    it "resolves future passed directly to final_answer" do
      mock_model.queue_code_action(<<~RUBY)
        result = get_data()
        final_answer(answer: result)
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(string_tool)
                        .build

      result = agent.run("Get and return")

      expect(result).to be_success
      expect(result.output).to eq("the data")
    end

    it "resolves future in string interpolation for final_answer" do
      mock_model.queue_code_action(<<~RUBY)
        result = get_data()
        final_answer(answer: "Result: \#{result}")
      RUBY

      agent = Smolagents.agent
                        .model { mock_model }
                        .tools(string_tool)
                        .build

      result = agent.run("Get and format")

      expect(result).to be_success
      expect(result.output).to eq("Result: the data")
    end
  end

  describe "Future combinators (ES6 Promise-inspired)" do
    let(:search_tool) do
      Smolagents::Tools.create(
        "search",
        description: "Search for a term",
        inputs: { query: { type: "string", description: "Search query" } },
        output_type: "string"
      ) { |query:| "Results for: #{query}" }
    end

    let(:slow_tool) do
      Smolagents::Tools.create(
        "slow_search",
        description: "Slower search",
        inputs: { query: { type: "string", description: "Search query" } },
        output_type: "string"
      ) { |query:| "Slow results for: #{query}" }
    end

    let(:failing_tool) do
      Smolagents::Tools.create(
        "failing_search",
        description: "Always fails",
        inputs: {},
        output_type: "string"
      ) { raise "Search failed!" }
    end

    describe "Future.all" do
      it "waits for all parallel searches and combines results" do
        mock_model.queue_code_action(<<~RUBY)
          a = search(query: "ruby")
          b = search(query: "python")
          c = search(query: "javascript")
          results = Future.all([a, b, c])
          final_answer(answer: results.join("; "))
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(search_tool)
                          .build

        result = agent.run("Search all languages")

        expect(result).to be_success
        expect(result.output).to include("Results for: ruby")
        expect(result.output).to include("Results for: python")
        expect(result.output).to include("Results for: javascript")
      end
    end

    describe "Future.all_settled" do
      it "collects all results including failures" do
        mock_model.queue_code_action(<<~RUBY)
          a = search(query: "good")
          b = failing_search()
          results = Future.all_settled([a, b])
          successes = results.count { |r| r[:status] == :fulfilled }
          failures = results.count { |r| r[:status] == :rejected }
          final_answer(answer: "Successes: \#{successes}, Failures: \#{failures}")
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(search_tool, failing_tool)
                          .build

        result = agent.run("Try both")

        expect(result).to be_success
        expect(result.output).to eq("Successes: 1, Failures: 1")
      end
    end

    describe "Future.race" do
      it "returns first completed result" do
        mock_model.queue_code_action(<<~RUBY)
          a = search(query: "fast")
          b = slow_search(query: "slow")
          winner = Future.race([a, b])
          final_answer(answer: winner)
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(search_tool, slow_tool)
                          .build

        result = agent.run("Race searches")

        expect(result).to be_success
        # Either could win since they complete at same time in tests
        expect(result.output).to match(/Results for:/)
      end
    end

    describe "Future.any" do
      it "returns first successful result, ignoring failures" do
        mock_model.queue_code_action(<<~RUBY)
          a = failing_search()
          b = search(query: "works")
          winner = Future.any([a, b])
          final_answer(answer: winner)
        RUBY

        agent = Smolagents.agent
                          .model { mock_model }
                          .tools(search_tool, failing_tool)
                          .build

        result = agent.run("Try until success")

        expect(result).to be_success
        expect(result.output).to eq("Results for: works")
      end
    end
  end
end
