require "spec_helper"

RSpec.describe Smolagents::Config do
  describe "constants" do
    it "defines MAX_STEPS_LIMIT" do
      expect(described_class::MAX_STEPS_LIMIT).to eq(1_000)
    end

    it "defines DEFAULT_LOCAL_BASE_URL" do
      expect(described_class::DEFAULT_LOCAL_BASE_URL).to eq("http://localhost:1234")
    end

    it "defines DEFAULT_LOCAL_API_URL" do
      expect(described_class::DEFAULT_LOCAL_API_URL).to eq("http://localhost:1234/v1")
    end

    it "defines AUTHORIZED_IMPORTS" do
      expect(described_class::AUTHORIZED_IMPORTS).to include("json", "uri", "time")
      expect(described_class::AUTHORIZED_IMPORTS).to be_frozen
    end

    it "defines SEARCH_PROVIDERS" do
      expect(described_class::SEARCH_PROVIDERS).to contain_exactly(
        :duckduckgo, :google
      )
    end

    it "defines DEFAULT_PLANNING_INTERVAL" do
      expect(described_class::DEFAULT_PLANNING_INTERVAL).to eq(3)
    end

    it "defines SEARCH_PROVIDER_TOOLS mapping" do
      expect(described_class::SEARCH_PROVIDER_TOOLS[:duckduckgo]).to eq(:duckduckgo_search)
      expect(described_class::SEARCH_PROVIDER_TOOLS[:google]).to eq(:google_search)
    end
  end

  describe "DEFAULTS" do
    subject(:defaults) { described_class::DEFAULTS }

    it "is frozen" do
      expect(defaults).to be_frozen
    end

    describe "top-level values" do
      it "has max_steps" do
        expect(defaults[:max_steps]).to eq(20)
      end

      it "has log_format" do
        expect(defaults[:log_format]).to eq(:text)
      end

      it "has log_level" do
        expect(defaults[:log_level]).to eq(:info)
      end

      it "has search_provider" do
        expect(defaults[:search_provider]).to eq(:duckduckgo)
      end

      it "has nil planning_interval by default" do
        expect(defaults[:planning_interval]).to be_nil
      end
    end

    describe ":http category" do
      subject(:http) { defaults[:http] }

      it "has timeout_seconds" do
        expect(http[:timeout_seconds]).to eq(30)
      end

      it "has ractor_timeout_seconds" do
        expect(http[:ractor_timeout_seconds]).to eq(120)
      end

      it "has rate_limit_status_codes" do
        expect(http[:rate_limit_status_codes]).to eq([429])
      end

      it "has max_model_id_length" do
        expect(http[:max_model_id_length]).to eq(64)
      end
    end

    describe ":execution category" do
      subject(:execution) { defaults[:execution] }

      it "has max_operations" do
        expect(execution[:max_operations]).to eq(100_000)
      end

      it "has max_output_length" do
        expect(execution[:max_output_length]).to eq(50_000)
      end

      it "has default_queue_depth" do
        expect(execution[:default_queue_depth]).to eq(100)
      end
    end

    describe ":isolation category" do
      subject(:isolation) { defaults[:isolation] }

      it "has default_timeout_seconds" do
        expect(isolation[:default_timeout_seconds]).to eq(5.0)
      end

      it "has default_max_memory_bytes" do
        expect(isolation[:default_max_memory_bytes]).to eq(50 * 1024 * 1024)
      end

      it "has max_ast_depth" do
        expect(isolation[:max_ast_depth]).to eq(100)
      end
    end

    describe ":memory category" do
      subject(:memory) { defaults[:memory] }

      it "has chars_per_token" do
        expect(memory[:chars_per_token]).to eq(4)
      end

      it "has max_reflections" do
        expect(memory[:max_reflections]).to eq(10)
      end
    end

    describe ":models category" do
      subject(:models) { defaults[:models] }

      it "has openai defaults" do
        expect(models[:openai][:default_max_tokens]).to eq(8192)
      end

      it "has anthropic defaults" do
        expect(models[:anthropic][:default_max_tokens]).to eq(4096)
      end
    end

    describe ":agents category" do
      subject(:agents) { defaults[:agents] }

      it "has refinement_max_iterations" do
        expect(agents[:refinement_max_iterations]).to eq(3)
      end

      it "has refinement_feedback_source" do
        expect(agents[:refinement_feedback_source]).to eq(:execution)
      end
    end

    describe ":security category" do
      subject(:security) { defaults[:security] }

      it "has max_prompt_length" do
        expect(security[:max_prompt_length]).to eq(5000)
      end

      it "has max_validation_errors" do
        expect(security[:max_validation_errors]).to eq(3)
      end
    end

    describe ":health category" do
      subject(:health) { defaults[:health] }

      it "has healthy_latency_ms" do
        expect(health[:healthy_latency_ms]).to eq(1000)
      end

      it "has degraded_latency_ms" do
        expect(health[:degraded_latency_ms]).to eq(5000)
      end

      it "has timeout_ms" do
        expect(health[:timeout_ms]).to eq(10_000)
      end
    end
  end

  describe ".default" do
    it "accesses single-level values" do
      expect(described_class.default(:max_steps)).to eq(20)
    end

    it "accesses nested values" do
      expect(described_class.default(:http, :timeout_seconds)).to eq(30)
    end

    it "returns nil for non-existent keys" do
      expect(described_class.default(:nonexistent)).to be_nil
    end

    it "returns nil for non-existent nested keys" do
      expect(described_class.default(:http, :nonexistent)).to be_nil
    end

    it "handles deep nesting" do
      expect(described_class.default(:models, :openai, :default_max_tokens)).to eq(8192)
    end
  end

  describe ".defaults_for" do
    it "returns category hash" do
      expect(described_class.defaults_for(:http)).to eq(described_class::DEFAULTS[:http])
    end

    it "returns nil for non-existent category" do
      expect(described_class.defaults_for(:nonexistent)).to be_nil
    end
  end
end
