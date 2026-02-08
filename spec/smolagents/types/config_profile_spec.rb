require "smolagents"

RSpec.describe Smolagents::Types::ConfigProfile do
  let(:instance) { described_class.new(name: :test, description: "Test profile", overrides: { max_steps: 5 }) }
  let(:instance_a) { described_class.local_gpu }
  let(:instance_b) { described_class.development }

  it_behaves_like "a data type"
  it_behaves_like "a type with to_h",
                  expected_keys: %i[name description overrides]

  describe ".default" do
    it "creates a profile with no overrides" do
      profile = described_class.default

      expect(profile.name).to eq(:default)
      expect(profile.description).to eq("Default settings — no overrides")
      expect(profile.overrides).to eq({})
    end
  end

  describe ".local_gpu" do
    it "creates a profile tuned for local GPU models" do
      profile = described_class.local_gpu

      expect(profile.name).to eq(:local_gpu)
      expect(profile.overrides[:http]).to eq(timeout_seconds: 60)
      expect(profile.overrides[:max_steps]).to eq(10)
      expect(profile.overrides[:health]).to include(latency_healthy_ms: 3000)
    end
  end

  describe ".development" do
    it "creates a profile with verbose logging" do
      profile = described_class.development

      expect(profile.name).to eq(:development)
      expect(profile.overrides[:log_level]).to eq(:debug)
    end
  end

  describe ".cloud_api" do
    it "creates a profile optimized for cloud providers" do
      profile = described_class.cloud_api

      expect(profile.name).to eq(:cloud_api)
      expect(profile.overrides[:http]).to eq(timeout_seconds: 30)
      expect(profile.overrides[:max_steps]).to eq(20)
    end
  end

  describe "#empty?" do
    it "returns true for default profile" do
      expect(described_class.default.empty?).to be true
    end

    it "returns false for profiles with overrides" do
      expect(described_class.local_gpu.empty?).to be false
    end
  end

  describe "#override_keys" do
    it "returns top-level configuration keys" do
      profile = described_class.local_gpu
      expect(profile.override_keys).to match_array(%i[http max_steps health])
    end

    it "returns empty array for default profile" do
      expect(described_class.default.override_keys).to eq([])
    end
  end

  describe "#merge" do
    it "deep merges overrides from both profiles" do
      gpu = described_class.local_gpu
      dev = described_class.development
      merged = gpu.merge(dev)

      expect(merged.overrides[:http]).to eq(timeout_seconds: 60)
      expect(merged.overrides[:max_steps]).to eq(10)
      expect(merged.overrides[:log_level]).to eq(:debug)
    end

    it "combines names with underscore" do
      merged = described_class.local_gpu.merge(described_class.development)
      expect(merged.name).to eq(:local_gpu_development)
    end

    it "combines descriptions" do
      gpu = described_class.local_gpu
      dev = described_class.development
      merged = gpu.merge(dev)

      expect(merged.description).to include(gpu.description)
      expect(merged.description).to include(dev.description)
    end

    it "later profile overrides earlier values" do
      base = described_class.new(name: :base, description: "Base", overrides: { max_steps: 5 })
      overlay = described_class.new(name: :overlay, description: "Overlay", overrides: { max_steps: 20 })
      merged = base.merge(overlay)

      expect(merged.overrides[:max_steps]).to eq(20)
    end

    it "deep merges nested hashes" do
      base = described_class.new(
        name: :base,
        description: "Base",
        overrides: { http: { timeout_seconds: 30, retries: 3 } }
      )
      overlay = described_class.new(
        name: :overlay,
        description: "Overlay",
        overrides: { http: { timeout_seconds: 60 } }
      )
      merged = base.merge(overlay)

      expect(merged.overrides[:http]).to eq(timeout_seconds: 60, retries: 3)
    end

    it "returns a new instance (immutable)" do
      gpu = described_class.local_gpu
      dev = described_class.development
      merged = gpu.merge(dev)

      expect(merged).not_to equal(gpu)
      expect(merged).not_to equal(dev)
      expect(gpu.name).to eq(:local_gpu)
      expect(dev.name).to eq(:development)
    end
  end

  describe "#to_h" do
    it "returns a hash with name, description, and overrides" do
      hash = instance.to_h

      expect(hash[:name]).to eq(:test)
      expect(hash[:description]).to eq("Test profile")
      expect(hash[:overrides]).to eq(max_steps: 5)
    end
  end

  describe "immutability" do
    it "is frozen on creation" do
      expect(instance).to be_frozen
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      profile = described_class.local_gpu

      case profile
      in { name: :local_gpu, overrides: }
        expect(overrides).to be_a(Hash)
      else
        raise "Pattern should match"
      end
    end
  end
end
