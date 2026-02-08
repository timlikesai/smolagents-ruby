require "spec_helper"

RSpec.describe Smolagents::Routing::ModelProfiles do
  describe ".for" do
    it "finds FunctionGemma profile" do
      profile = described_class.for("functiongemma-270m-it-mlx")

      expect(profile).not_to be_nil
      expect(profile.display_name).to eq("FunctionGemma 270M")
      expect(profile.accuracy).to eq(0.667)
    end

    it "finds Granite Micro profile" do
      profile = described_class.for("granite-4.0-h-micro-mlx")

      expect(profile.display_name).to eq("Granite 4.0 Micro")
      expect(profile.accuracy).to eq(1.0)
    end

    it "finds LFM profile" do
      profile = described_class.for("lfm2.5-1.2b-instruct-mlx")

      expect(profile.display_name).to eq("LFM 1.2B Instruct")
      expect(profile.accuracy).to eq(0.833)
    end

    it "returns nil for unknown models" do
      expect(described_class.for("unknown-model")).to be_nil
    end
  end

  describe ".config_for" do
    it "returns tuned config for known model" do
      config = described_class.config_for("functiongemma-270m-it-mlx")

      expect(config).to be_a(Smolagents::Types::ToolRouterConfig)
      expect(config.model_id).to eq("functiongemma-270m-it-mlx")
      expect(config.high_confidence_threshold).to eq(0.85) # Tuned higher for FG
    end

    it "returns conservative config for unknown model" do
      config = described_class.config_for("unknown-model-xyz")

      expect(config.model_id).to eq("unknown-model-xyz")
      expect(config.high_confidence_threshold).to eq(0.9) # Conservative
    end
  end

  describe ".recommended" do
    it "returns profiles with accuracy >= 70%" do
      recommended = described_class.recommended

      expect(recommended).not_to be_empty
      expect(recommended.all? { |p| p.accuracy >= 0.7 }).to be true
    end

    it "includes Granite Micro and LFM" do
      names = described_class.recommended.map(&:display_name)

      expect(names).to include("Granite 4.0 Micro")
      expect(names).to include("LFM 1.2B Instruct")
    end
  end

  describe ".best_balanced" do
    it "returns profile that is both fast and accurate" do
      best = described_class.best_balanced

      # LFM 1.2B should be best balanced (83.3% accuracy, 890ms)
      expect(best.display_name).to eq("LFM 1.2B Instruct")
    end
  end

  describe ".fastest_recommended" do
    it "returns fastest profile with good accuracy" do
      fastest = described_class.fastest_recommended

      # Should be LFM 1.2B (890ms) since FunctionGemma is faster but < 70%
      expect(fastest.avg_latency_ms).to be < 1000
      expect(fastest.accuracy).to be >= 0.7
    end
  end

  describe ".most_accurate" do
    it "returns most accurate profile" do
      best = described_class.most_accurate

      expect(best.display_name).to eq("Granite 4.0 Micro")
      expect(best.accuracy).to eq(1.0)
    end
  end

  describe "Profile" do
    let(:profile) { described_class.for("functiongemma-270m-it-mlx") }

    describe "#matches?" do
      it "matches by pattern" do
        expect(profile.matches?("functiongemma-270m-it-mlx")).to be true
        expect(profile.matches?("FUNCTIONGEMMA-anything")).to be true
        expect(profile.matches?("other-model")).to be false
      end
    end

    describe "#to_config" do
      it "converts to ToolRouterConfig" do
        config = profile.to_config

        expect(config).to be_a(Smolagents::Types::ToolRouterConfig)
        expect(config.enabled?).to be true
        expect(config.high_confidence_threshold).to eq(profile.high_threshold)
        expect(config.low_confidence_threshold).to eq(profile.low_threshold)
      end
    end

    describe "predicates" do
      it "identifies recommended profiles" do
        granite = described_class.for("granite-4.0-h-micro-mlx")
        qwen = described_class.for("qwen3-0.6b-mlx")

        expect(granite.recommended?).to be true
        expect(qwen.recommended?).to be false
      end

      it "identifies fast profiles" do
        fg = described_class.for("functiongemma-270m-it-mlx")
        gemma = described_class.for("gemma-3n-e4b-it-mlx")

        expect(fg.fast?).to be true
        expect(gemma.fast?).to be false
      end

      it "identifies balanced profiles" do
        lfm = described_class.for("lfm2.5-1.2b-instruct-mlx")

        expect(lfm.balanced?).to be true
      end
    end
  end
end
