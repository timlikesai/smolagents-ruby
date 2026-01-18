require "smolagents"

RSpec.describe Smolagents::Config::ModelPalette do
  describe ".create" do
    it "creates an empty palette" do
      palette = described_class.create

      expect(palette.registry).to eq({})
      expect(palette.names).to eq([])
    end
  end

  describe "#register" do
    it "registers a callable factory" do
      palette = described_class.create
                               .register(:gpt4, -> { "gpt4-model" })

      expect(palette.registered?(:gpt4)).to be true
      expect(palette.names).to eq([:gpt4])
    end

    it "accepts string names and converts to symbols" do
      palette = described_class.create
                               .register("gpt4", -> { "gpt4-model" })

      expect(palette.registered?(:gpt4)).to be true
      expect(palette.registered?("gpt4")).to be true
    end

    it "returns new palette (immutable)" do
      original = described_class.create
      updated = original.register(:gpt4, -> { "gpt4-model" })

      expect(original.registered?(:gpt4)).to be false
      expect(updated.registered?(:gpt4)).to be true
    end

    it "allows chaining multiple registrations" do
      palette = described_class.create
                               .register(:gpt4, -> { "gpt4" })
                               .register(:claude, -> { "claude" })
                               .register(:local, -> { "local" })

      expect(palette.names).to eq(%i[gpt4 claude local])
    end

    it "raises ArgumentError for non-callable factory" do
      palette = described_class.create

      expect { palette.register(:bad, "not callable") }
        .to raise_error(ArgumentError, /Factory must be callable/)
    end

    it "accepts any callable (proc, lambda, method)" do
      model_class = Class.new do
        def self.build
          "built-model"
        end
      end

      palette = described_class.create
                               .register(:proc_model, proc { "proc" })
                               .register(:lambda_model, -> { "lambda" })
                               .register(:method_model, model_class.method(:build))

      expect(palette.get(:proc_model)).to eq("proc")
      expect(palette.get(:lambda_model)).to eq("lambda")
      expect(palette.get(:method_model)).to eq("built-model")
    end

    it "allows overwriting existing registrations" do
      palette = described_class.create
                               .register(:model, -> { "v1" })
                               .register(:model, -> { "v2" })

      expect(palette.get(:model)).to eq("v2")
    end
  end

  describe "#get" do
    it "calls factory and returns result" do
      call_count = 0
      palette = described_class.create
                               .register(:counter, -> { call_count += 1 })

      expect(palette.get(:counter)).to eq(1)
      expect(palette.get(:counter)).to eq(2)
      expect(call_count).to eq(2)
    end

    it "accepts string or symbol names" do
      palette = described_class.create
                               .register(:gpt4, -> { "model" })

      expect(palette.get(:gpt4)).to eq("model")
      expect(palette.get("gpt4")).to eq("model")
    end

    it "raises ArgumentError for unregistered model" do
      palette = described_class.create
                               .register(:gpt4, -> { "gpt4" })

      expect { palette.get(:unknown) }
        .to raise_error(ArgumentError, /Model not registered: unknown/)
    end

    it "includes available models in error message" do
      palette = described_class.create
                               .register(:gpt4, -> { "gpt4" })
                               .register(:claude, -> { "claude" })

      expect { palette.get(:unknown) }
        .to raise_error(ArgumentError, /Available: gpt4, claude/)
    end
  end

  describe "#registered?" do
    it "returns true for registered models" do
      palette = described_class.create.register(:gpt4, -> { "gpt4" })

      expect(palette.registered?(:gpt4)).to be true
    end

    it "returns false for unregistered models" do
      palette = described_class.create

      expect(palette.registered?(:gpt4)).to be false
    end

    it "handles both string and symbol names" do
      palette = described_class.create.register(:gpt4, -> { "gpt4" })

      expect(palette.registered?(:gpt4)).to be true
      expect(palette.registered?("gpt4")).to be true
    end
  end

  describe "#names" do
    it "returns empty array for empty palette" do
      palette = described_class.create

      expect(palette.names).to eq([])
    end

    it "returns all registered model names" do
      palette = described_class.create
                               .register(:a, -> { "a" })
                               .register(:b, -> { "b" })
                               .register(:c, -> { "c" })

      expect(palette.names).to eq(%i[a b c])
    end
  end

  describe "immutability" do
    it "is frozen (Data.define)" do
      palette = described_class.create

      expect(palette.frozen?).to be true
    end

    it "registry cannot be modified externally" do
      palette = described_class.create

      expect { palette.registry[:hack] = -> { "hacked" } }.to raise_error(FrozenError)
    end
  end

  describe "usage patterns" do
    it "supports typical model registration workflow" do
      # Create simple mock model using hashes
      fast_factory = -> { { name: "gpt-3.5-turbo", speed: :fast } }
      smart_factory = -> { { name: "gpt-4", speed: :slow } }
      local_factory = -> { { name: "llama", speed: :medium } }

      # Create palette with common models
      palette = described_class.create
                               .register(:fast, fast_factory)
                               .register(:smart, smart_factory)
                               .register(:local, local_factory)

      # Get model by use case
      fast_model = palette.get(:fast)
      expect(fast_model[:name]).to eq("gpt-3.5-turbo")
      expect(fast_model[:speed]).to eq(:fast)

      # Check available options
      expect(palette.names).to include(:fast, :smart, :local)
    end
  end
end
