RSpec.describe Smolagents::Errors::ToolError do
  describe "Data.define structure" do
    it "is a Data type" do
      expect(described_class).to be < Data
    end

    it "has code, message, suggestion, and example members" do
      error = described_class.new(
        code: :invalid_format,
        message: "Expected string",
        suggestion: "Pass a string",
        example: 'call(arg: "value")'
      )
      expect(error.code).to eq(:invalid_format)
      expect(error.message).to eq("Expected string")
      expect(error.suggestion).to eq("Pass a string")
      expect(error.example).to eq('call(arg: "value")')
    end

    it "is immutable" do
      error = described_class.new(code: :test, message: "msg", suggestion: nil, example: nil)
      expect { error.code = :other }.to raise_error(NoMethodError)
    end
  end

  describe "#to_observation" do
    it "formats error with code and message" do
      error = described_class.new(code: :invalid_format, message: "Expected string", suggestion: nil, example: nil)
      expect(error.to_observation).to eq("Error [invalid_format]: Expected string")
    end

    it "includes suggestion when present" do
      error = described_class.new(
        code: :missing_argument,
        message: "Required argument 'query' is missing",
        suggestion: "Provide the 'query' argument",
        example: nil
      )
      expect(error.to_observation).to include("Fix: Provide the 'query' argument")
    end

    it "includes example when present" do
      error = described_class.new(
        code: :invalid_value,
        message: "Invalid value",
        suggestion: nil,
        example: 'search(query: "test")'
      )
      expect(error.to_observation).to include('Example: search(query: "test")')
    end

    it "includes all parts when all present" do
      error = described_class.new(
        code: :invalid_format,
        message: "Expected integer",
        suggestion: "Convert to integer first",
        example: "calculate(n: 42)"
      )
      observation = error.to_observation
      expect(observation).to include("Error [invalid_format]: Expected integer")
      expect(observation).to include("Fix: Convert to integer first")
      expect(observation).to include("Example: calculate(n: 42)")
    end
  end

  describe "#to_s" do
    it "returns the observation" do
      error = described_class.new(code: :test, message: "test message", suggestion: nil, example: nil)
      expect(error.to_s).to eq(error.to_observation)
    end
  end

  describe "pattern matching" do
    it "supports pattern matching on members" do
      error = described_class.new(
        code: :invalid_format,
        message: "Expected string",
        suggestion: "Use quotes",
        example: nil
      )

      case error
      in { code: :invalid_format, suggestion: }
        expect(suggestion).to eq("Use quotes")
      else
        raise "Pattern not matched"
      end
    end
  end

  describe ".raise!" do
    it "raises ToolExecutionError with formatted message" do
      expect do
        described_class.raise!(
          code: :missing_argument,
          message: "Required argument 'url' is missing",
          suggestion: "Provide the URL",
          tool_name: "visit_webpage"
        )
      end.to raise_error(Smolagents::ToolExecutionError) do |error|
        expect(error.message).to include("Error [missing_argument]")
        expect(error.tool_name).to eq("visit_webpage")
      end
    end
  end

  describe "factory methods" do
    describe ".invalid_format" do
      it "creates an invalid_format error" do
        error = described_class.invalid_format(expected: "string", got: "integer")
        expect(error.code).to eq(:invalid_format)
        expect(error.message).to eq("Expected string, got integer")
        expect(error.suggestion).to include("string")
      end

      it "accepts custom suggestion and example" do
        error = described_class.invalid_format(
          expected: "URL",
          got: "path",
          suggestion: "Use full URL with https://",
          example: 'visit(url: "https://example.com")'
        )
        expect(error.suggestion).to eq("Use full URL with https://")
        expect(error.example).to eq('visit(url: "https://example.com")')
      end
    end

    describe ".missing_argument" do
      it "creates a missing_argument error" do
        error = described_class.missing_argument(name: "query")
        expect(error.code).to eq(:missing_argument)
        expect(error.message).to eq("Required argument 'query' is missing")
        expect(error.suggestion).to include("query")
      end

      it "accepts custom suggestion and example" do
        error = described_class.missing_argument(
          name: "query",
          suggestion: "Provide a search term",
          example: 'search(query: "Ruby 4.0")'
        )
        expect(error.suggestion).to eq("Provide a search term")
        expect(error.example).to eq('search(query: "Ruby 4.0")')
      end
    end

    describe ".invalid_value" do
      it "creates an invalid_value error" do
        error = described_class.invalid_value(
          name: "max_results",
          value: -1,
          reason: "must be positive"
        )
        expect(error.code).to eq(:invalid_value)
        expect(error.message).to eq("Invalid value '-1' for 'max_results': must be positive")
      end

      it "accepts custom suggestion and example" do
        error = described_class.invalid_value(
          name: "timeout",
          value: "abc",
          reason: "not a number",
          suggestion: "Use a numeric value in seconds",
          example: "fetch(timeout: 30)"
        )
        expect(error.suggestion).to eq("Use a numeric value in seconds")
        expect(error.example).to eq("fetch(timeout: 30)")
      end
    end

    describe ".not_found" do
      it "creates a not_found error" do
        error = described_class.not_found(resource: "Page", identifier: "/missing")
        expect(error.code).to eq(:not_found)
        expect(error.message).to eq("Page '/missing' not found")
        expect(error.suggestion).to include("page")
      end

      it "accepts custom suggestion" do
        error = described_class.not_found(
          resource: "API Endpoint",
          identifier: "/v2/users",
          suggestion: "Check if API version is correct"
        )
        expect(error.suggestion).to eq("Check if API version is correct")
      end
    end

    describe ".rate_limited" do
      it "creates a rate_limited error without retry_after" do
        error = described_class.rate_limited
        expect(error.code).to eq(:rate_limited)
        expect(error.message).to include("rate limited")
        expect(error.suggestion).to include("Wait")
      end

      it "creates a rate_limited error with retry_after" do
        error = described_class.rate_limited(retry_after: 60)
        expect(error.message).to include("60s")
      end
    end

    describe ".timeout" do
      it "creates a timeout error" do
        error = described_class.timeout(operation: "HTTP request", duration: 30)
        expect(error.code).to eq(:timeout)
        expect(error.message).to eq("HTTP request timed out after 30s")
        expect(error.suggestion).to include("simpler")
      end
    end
  end

  describe "re-export" do
    it "is accessible at Smolagents::ToolError" do
      expect(Smolagents::ToolError).to eq(described_class)
    end
  end
end
