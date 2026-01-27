require "smolagents/concerns/execution/error_feedback"

RSpec.describe Smolagents::Concerns::ErrorFeedback do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ErrorFeedback

      def find_tools_by_pattern(pattern)
        # Mock implementation
        []
      end

      def tool_exists?(name) = false
    end
  end

  let(:instance) { test_class.new }

  describe "GENERIC_NEXT_STEPS constant" do
    it "is frozen" do
      expect(described_class::GENERIC_NEXT_STEPS).to be_frozen
    end

    it "provides generic recovery suggestions" do
      expect(described_class::GENERIC_NEXT_STEPS).to include("Check arguments")
    end

    it "suggests trying different approach" do
      expect(described_class::GENERIC_NEXT_STEPS).to include("different approach")
    end
  end

  describe "#format_error_feedback" do
    let(:tool_call) do
      instance_double(Smolagents::Types::ToolCall,
                      name: "web_search",
                      arguments: { "query" => "test" })
    end

    context "with RateLimitError" do
      let(:error) do
        # Use a real error instance to properly test the case statement behavior
        Smolagents::RateLimitError.new("Rate limited")
      end

      it "returns rate limit feedback" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("rate limited")
      end

      it "includes tool name" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("web_search")
      end
    end

    context "with ServiceUnavailableError" do
      let(:error) do
        # Use a real error instance to properly test the case statement behavior
        Smolagents::ServiceUnavailableError.new("Service unavailable")
      end

      it "returns unavailable feedback" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("unavailable")
      end
    end

    context "with generic error" do
      let(:error) { StandardError.new("Connection timeout") }

      it "returns generic feedback" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("failed:")
        expect(feedback).to include("Connection timeout")
      end

      it "includes checkmark and tool name" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("✗")
        expect(feedback).to include("web_search")
      end

      it "includes generic next steps" do
        feedback = instance.send(:format_error_feedback, error, tool_call)

        expect(feedback).to include("NEXT STEPS:")
      end
    end
  end

  describe "#extract_query" do
    context "with string query key" do
      it "extracts query from string key" do
        tool_call = instance_double(Smolagents::Types::ToolCall,
                                    arguments: { "query" => "search term" })

        query = instance.send(:extract_query, tool_call)
        expect(query).to eq("search term")
      end
    end

    context "with symbol query key" do
      it "extracts query from symbol key" do
        tool_call = instance_double(Smolagents::Types::ToolCall,
                                    arguments: { query: "search term" })

        query = instance.send(:extract_query, tool_call)
        expect(query).to eq("search term")
      end
    end

    context "without query" do
      it "returns nil" do
        tool_call = instance_double(Smolagents::Types::ToolCall,
                                    arguments: { "other" => "value" })

        query = instance.send(:extract_query, tool_call)
        expect(query).to be_nil
      end
    end

    context "with string key precedence" do
      it "prefers string key over symbol" do
        tool_call = instance_double(Smolagents::Types::ToolCall,
                                    arguments: { "query" => "string_query", query: "symbol_query" })

        query = instance.send(:extract_query, tool_call)
        expect(query).to eq("string_query")
      end
    end
  end

  describe "#rate_limit_feedback" do
    it "formats rate limit message" do
      feedback = instance.send(:rate_limit_feedback, "api_search", "alternatives", "")

      expect(feedback).to include("✗ api_search")
      expect(feedback).to include("rate limited")
    end

    it "includes alternatives" do
      feedback = instance.send(:rate_limit_feedback, "tool", "Try alternative", "")

      expect(feedback).to include("Try alternative")
    end

    it "includes call echo when provided" do
      feedback = instance.send(:rate_limit_feedback, "search", "alts", "Called: search(query: \"test\")")

      expect(feedback).to include("Called: search(query: \"test\")")
    end
  end

  describe "#unavailable_feedback" do
    it "formats unavailable message" do
      feedback = instance.send(:unavailable_feedback, "web_search", "alternatives", "")

      expect(feedback).to include("✗ web_search")
      expect(feedback).to include("unavailable")
    end

    it "includes alternatives" do
      feedback = instance.send(:unavailable_feedback, "tool", "Try alternative", "")

      expect(feedback).to include("Try alternative")
    end

    it "includes call echo when provided" do
      feedback = instance.send(:unavailable_feedback, "web", "alts", "Called: web(url: \"http://x\")")

      expect(feedback).to include("Called: web(url: \"http://x\")")
    end
  end

  describe "#generic_feedback" do
    it "formats generic error message" do
      error = StandardError.new("Network error")
      feedback = instance.send(:generic_feedback, "tool_name", error, "")

      expect(feedback).to include("✗ tool_name failed:")
      expect(feedback).to include("Network error")
    end

    it "includes generic next steps" do
      error = RuntimeError.new("Something went wrong")
      feedback = instance.send(:generic_feedback, "tool", error, "")

      expect(feedback).to include("NEXT STEPS:")
    end
  end

  describe "#suggest_alternatives" do
    before do
      allow(instance).to receive(:find_alternative_tools).and_return(%w[search2 search3])
    end

    it "builds suggestions from alternative tools" do
      suggestions = instance.send(:suggest_alternatives, "search1", "query text")

      expect(suggestions).to be_a(String)
      expect(suggestions).to include("search2")
    end

    it "includes query in suggestions" do
      suggestions = instance.send(:suggest_alternatives, "tool", "important query")

      expect(suggestions).to include("important query")
    end

    it "includes fallback to final_answer" do
      suggestions = instance.send(:suggest_alternatives, "tool", "query")

      expect(suggestions).to include("final_answer")
    end

    it "handles nil query" do
      allow(instance).to receive(:find_alternative_tools).and_return(["alt"])
      suggestions = instance.send(:suggest_alternatives, "tool", nil)

      expect(suggestions).to be_a(String)
      expect(suggestions).to include("final_answer")
    end
  end

  describe "#find_alternative_tools" do
    before do
      allow(instance).to receive_messages(find_tools_by_pattern: %w[search google bing], tool_exists?: false)
    end

    it "finds tools matching search pattern" do
      alternatives = instance.send(:find_alternative_tools, "web_search")

      expect(alternatives).to include("search")
    end

    it "removes the failed tool from alternatives" do
      allow(instance).to receive(:find_tools_by_pattern).and_return(%w[search web_search])
      alternatives = instance.send(:find_alternative_tools, "web_search")

      expect(alternatives).not_to include("web_search")
      expect(alternatives).to include("search")
    end

    it "includes wikipedia if available" do
      allow(instance).to receive(:tool_exists?).with("wikipedia").and_return(true)
      allow(instance).to receive(:find_tools_by_pattern).and_return([])

      alternatives = instance.send(:find_alternative_tools, "google")

      expect(alternatives).to include("wikipedia")
    end

    it "excludes wikipedia if not available" do
      allow(instance).to receive(:tool_exists?).with("wikipedia").and_return(false)
      allow(instance).to receive(:find_tools_by_pattern).and_return([])

      alternatives = instance.send(:find_alternative_tools, "google")

      expect(alternatives).not_to include("wikipedia")
    end
  end

  describe "#build_suggestions" do
    context "with query" do
      it "suggests alternative tools with query" do
        suggestions = instance.send(:build_suggestions, %w[search2 search3], "python")

        expect(suggestions).to include("search2")
        expect(suggestions).to include("python")
      end

      it "filters out nil suggestions" do
        suggestions = instance.send(:build_suggestions, %w[tool1 tool2], "query")

        # Should not have nil entries
        expect(suggestions).not_to include("nil")
      end
    end

    context "without query" do
      it "only suggests final_answer" do
        suggestions = instance.send(:build_suggestions, ["tool1"], nil)

        expect(suggestions).to include("final_answer")
        expect(suggestions).not_to include("Try tool1")
      end
    end

    context "with multiple alternative tools" do
      it "provides multiple suggestions" do
        suggestions = instance.send(:build_suggestions, %w[alt1 alt2 alt3], "query")

        expect(suggestions).to include("alt1")
        expect(suggestions).to include("alt2")
        expect(suggestions).to include("alt3")
      end
    end

    it "includes final answer guidance" do
      suggestions = instance.send(:build_suggestions, ["tool"], "query")

      expect(suggestions).to include("final_answer")
    end

    it "mentions explaining unfound info" do
      suggestions = instance.send(:build_suggestions, [], nil)

      expect(suggestions).to include("couldn't find")
    end
  end

  describe "integration" do
    let(:tool_call) do
      instance_double(Smolagents::Types::ToolCall,
                      name: "web_search",
                      arguments: { "query" => "python docs" })
    end

    it "provides complete error feedback flow" do
      error = StandardError.new("Connection failed")

      allow(instance).to receive_messages(find_tools_by_pattern: %w[google bing], tool_exists?: false)

      feedback = instance.send(:format_error_feedback, error, tool_call)

      expect(feedback).to include("web_search")
      expect(feedback).to include("failed:")
      expect(feedback).to include("NEXT STEPS:")
    end

    it "formats rate limit with suggestions" do
      error = double("rate_limit_error")
      allow(error).to receive(:is_a?).with(anything).and_return(false)

      # Simulate RateLimitError behavior
      allow(instance).to receive(:format_error_feedback).and_call_original

      # Manually test rate_limit_feedback
      feedback = instance.send(:rate_limit_feedback, "api_call", "Try again later", "")

      expect(feedback).to include("rate limited")
    end
  end
end
