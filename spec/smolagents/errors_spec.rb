RSpec.describe Smolagents do
  describe "Error Hierarchy" do
    describe Smolagents::AgentError do
      it "inherits from StandardError" do
        expect(described_class.superclass).to eq(StandardError)
      end

      it "supports pattern matching" do
        error = described_class.new("test error")
        case error
        in { message: msg }
          expect(msg).to eq("test error")
        end
      end
    end

    describe Smolagents::AgentExecutionError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores step_number" do
        error = described_class.new("execution failed", step_number: 5)
        expect(error.step_number).to eq(5)
        expect(error.message).to eq("execution failed")
      end

      it "supports pattern matching with step_number" do
        error = described_class.new("failed", step_number: 3)
        case error
        in { message: msg, step_number: step }
          expect(msg).to eq("failed")
          expect(step).to eq(3)
        end
      end
    end

    describe Smolagents::AgentGenerationError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores model_id and response" do
        error = described_class.new("generation failed", model_id: "gpt-4", response: { error: "rate limit" })
        expect(error.model_id).to eq("gpt-4")
        expect(error.response).to eq({ error: "rate limit" })
      end

      it "supports pattern matching" do
        error = described_class.new("failed", model_id: "claude", response: nil)
        case error
        in { model_id: mid }
          expect(mid).to eq("claude")
        end
      end
    end

    describe Smolagents::AgentParsingError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores raw_output and expected_format" do
        error = described_class.new("parse failed", raw_output: "garbage", expected_format: "json")
        expect(error.raw_output).to eq("garbage")
        expect(error.expected_format).to eq("json")
      end

      it "supports pattern matching" do
        error = described_class.new("failed", raw_output: "bad", expected_format: "code")
        case error
        in { raw_output: raw, expected_format: fmt }
          expect(raw).to eq("bad")
          expect(fmt).to eq("code")
        end
      end
    end

    describe Smolagents::AgentMaxStepsError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores max_steps and steps_taken" do
        error = described_class.new(max_steps: 10, steps_taken: 10)
        expect(error.max_steps).to eq(10)
        expect(error.steps_taken).to eq(10)
      end

      it "generates default message with max_steps" do
        error = described_class.new(max_steps: 5)
        expect(error.message).to include("5")
      end

      it "supports pattern matching" do
        error = described_class.new(max_steps: 10, steps_taken: 10)
        case error
        in { max_steps: max, steps_taken: taken }
          expect(max).to eq(10)
          expect(taken).to eq(10)
        end
      end
    end

    describe Smolagents::ToolExecutionError do
      it "inherits from AgentExecutionError" do
        expect(described_class.superclass).to eq(Smolagents::AgentExecutionError)
      end

      it "stores tool_name, arguments, and step_number" do
        error = described_class.new(
          "tool failed",
          tool_name: "search",
          arguments: { query: "test" },
          step_number: 2
        )
        expect(error.tool_name).to eq("search")
        expect(error.arguments).to eq({ query: "test" })
        expect(error.step_number).to eq(2)
      end

      it "supports pattern matching with all attributes" do
        error = described_class.new("failed", tool_name: "calc", arguments: {}, step_number: 1)
        case error
        in { tool_name: name, step_number: step }
          expect(name).to eq("calc")
          expect(step).to eq(1)
        end
      end
    end

    describe "AgentToolCallError alias" do
      it "is an alias for ToolExecutionError" do
        expect(Smolagents::AgentToolCallError).to eq(Smolagents::ToolExecutionError)
      end
    end

    describe "AgentToolExecutionError alias" do
      it "is an alias for ToolExecutionError" do
        expect(Smolagents::AgentToolExecutionError).to eq(Smolagents::ToolExecutionError)
      end
    end

    describe Smolagents::MCPError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores server_name" do
        error = described_class.new("MCP failed", server_name: "my-server")
        expect(error.server_name).to eq("my-server")
      end

      it "supports pattern matching" do
        error = described_class.new("failed", server_name: "test-server")
        case error
        in { server_name: name }
          expect(name).to eq("test-server")
        end
      end
    end

    describe Smolagents::MCPConnectionError do
      it "inherits from MCPError" do
        expect(described_class.superclass).to eq(Smolagents::MCPError)
      end

      it "stores server_name and url" do
        error = described_class.new("connection failed", server_name: "my-server", url: "http://localhost:3000")
        expect(error.server_name).to eq("my-server")
        expect(error.url).to eq("http://localhost:3000")
      end

      it "supports pattern matching with all attributes" do
        error = described_class.new("failed", server_name: "s", url: "http://test")
        case error
        in { server_name: name, url: u }
          expect(name).to eq("s")
          expect(u).to eq("http://test")
        end
      end
    end

    describe Smolagents::ExecutorError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores language and code_snippet" do
        error = described_class.new("execution failed", language: :ruby, code_snippet: "puts 'hi'")
        expect(error.language).to eq(:ruby)
        expect(error.code_snippet).to eq("puts 'hi'")
      end

      it "supports pattern matching" do
        error = described_class.new("failed", language: :python, code_snippet: nil)
        case error
        in { language: lang }
          expect(lang).to eq(:python)
        end
      end
    end

    describe Smolagents::InterpreterError do
      it "inherits from ExecutorError" do
        expect(described_class.superclass).to eq(Smolagents::ExecutorError)
      end

      it "stores language, code_snippet, and line_number" do
        error = described_class.new(
          "syntax error",
          language: :ruby,
          code_snippet: "def foo(",
          line_number: 42
        )
        expect(error.language).to eq(:ruby)
        expect(error.code_snippet).to eq("def foo(")
        expect(error.line_number).to eq(42)
      end

      it "defaults language to :ruby" do
        error = described_class.new("error")
        expect(error.language).to eq(:ruby)
      end

      it "supports pattern matching with all attributes" do
        error = described_class.new("failed", line_number: 10)
        case error
        in { line_number: line, language: lang }
          expect(line).to eq(10)
          expect(lang).to eq(:ruby)
        end
      end
    end

    describe Smolagents::ApiError do
      it "inherits from AgentError" do
        expect(described_class.superclass).to eq(Smolagents::AgentError)
      end

      it "stores status_code and response_body" do
        error = described_class.new("API failed", status_code: 429, response_body: "rate limited")
        expect(error.status_code).to eq(429)
        expect(error.response_body).to eq("rate limited")
      end

      it "supports pattern matching" do
        error = described_class.new("failed", status_code: 500, response_body: nil)
        case error
        in { status_code: code }
          expect(code).to eq(500)
        end
      end
    end

    describe Smolagents::FinalAnswerException do
      it "inherits from StandardError" do
        expect(described_class.superclass).to eq(StandardError)
      end

      it "stores value" do
        error = described_class.new("the answer")
        expect(error.value).to eq("the answer")
      end

      it "includes value in message" do
        error = described_class.new(42)
        expect(error.message).to include("42")
      end

      it "supports pattern matching" do
        error = described_class.new({ result: "done" })
        case error
        in { value: v }
          expect(v).to eq({ result: "done" })
        end
      end

      it "redacts API keys from message" do
        error = described_class.new({ result: "ok", api_key: "sk-secret123456789012345678901234" })
        expect(error.message).to include("[REDACTED]")
        expect(error.message).not_to include("sk-secret")
      end

      it "preserves original value with API keys" do
        value = { result: "ok", api_key: "sk-secret123456789012345678901234" }
        error = described_class.new(value)
        # Value should be preserved (for actual use), only message is redacted
        expect(error.value[:api_key]).to eq("sk-secret123456789012345678901234")
      end
    end

    describe "hierarchy relationships" do
      it "catches ToolExecutionError as AgentExecutionError" do
        expect do
          raise Smolagents::ToolExecutionError.new("tool failed", tool_name: "test")
        end.to raise_error(Smolagents::AgentExecutionError)
      end

      it "catches AgentExecutionError as AgentError" do
        expect do
          raise Smolagents::AgentExecutionError, "failed"
        end.to raise_error(Smolagents::AgentError)
      end

      it "catches MCPConnectionError as MCPError" do
        expect do
          raise Smolagents::MCPConnectionError, "failed"
        end.to raise_error(Smolagents::MCPError)
      end

      it "catches MCPError as AgentError" do
        expect do
          raise Smolagents::MCPError, "failed"
        end.to raise_error(Smolagents::AgentError)
      end

      it "catches InterpreterError as ExecutorError" do
        expect do
          raise Smolagents::InterpreterError, "failed"
        end.to raise_error(Smolagents::ExecutorError)
      end

      it "catches ExecutorError as AgentError" do
        expect do
          raise Smolagents::ExecutorError, "failed"
        end.to raise_error(Smolagents::AgentError)
      end

      it "catches ApiError as AgentError" do
        expect do
          raise Smolagents::ApiError, "failed"
        end.to raise_error(Smolagents::AgentError)
      end
    end

    describe "practical usage examples" do
      def risky_operation
        raise Smolagents::ToolExecutionError.new(
          "API timeout",
          tool_name: "web_search",
          arguments: { query: "test" },
          step_number: 3
        )
      end

      it "allows targeted rescue with pattern matching" do
        risky_operation
      rescue Smolagents::ToolExecutionError => e
        case e
        in { tool_name: "web_search", step_number: step }
          expect(step).to eq(3)
        end
      end

      it "allows rescue by hierarchy level" do
        rescued = false
        begin
          risky_operation
        rescue Smolagents::AgentError
          rescued = true
        end
        expect(rescued).to be true
      end
    end
  end
end
