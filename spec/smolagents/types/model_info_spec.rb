require "smolagents"

RSpec.describe Smolagents::Types::ModelInfo do
  describe ".new" do
    it "creates model info" do
      info = described_class.new(
        id: "gpt-4",
        object: "model",
        created: 1_686_935_002,
        owned_by: "openai",
        loaded: true
      )

      expect(info.id).to eq("gpt-4")
      expect(info.object).to eq("model")
      expect(info.created).to eq(1_686_935_002)
      expect(info.owned_by).to eq("openai")
      expect(info.loaded).to be true
    end

    it "is immutable" do
      info = described_class.new(
        id: "gpt-4", object: "model", created: nil, owned_by: nil, loaded: false
      )
      expect(info).to be_frozen
    end
  end

  describe "#loaded?" do
    it "returns true when loaded is true" do
      info = described_class.new(
        id: "x", object: "model", created: nil, owned_by: nil, loaded: true
      )
      expect(info.loaded?).to be true
    end

    it "returns false when loaded is false" do
      info = described_class.new(
        id: "x", object: "model", created: nil, owned_by: nil, loaded: false
      )
      expect(info.loaded?).to be false
    end

    it "returns false when loaded is nil" do
      info = described_class.new(
        id: "x", object: "model", created: nil, owned_by: nil, loaded: nil
      )
      expect(info.loaded?).to be false
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      info = described_class.new(
        id: "gpt-4",
        object: "model",
        created: 1_686_935_002,
        owned_by: "openai",
        loaded: true
      )

      expect(info.to_h).to eq({
                                id: "gpt-4",
                                object: "model",
                                created: 1_686_935_002,
                                owned_by: "openai",
                                loaded: true
                              })
    end
  end

  describe ".from_api" do
    it "creates from string-keyed hash" do
      info = described_class.from_api({
                                        "id" => "gpt-4",
                                        "object" => "model",
                                        "created" => 1_686_935_002,
                                        "owned_by" => "openai",
                                        "loaded" => true
                                      })

      expect(info.id).to eq("gpt-4")
      expect(info.object).to eq("model")
      expect(info.created).to eq(1_686_935_002)
      expect(info.owned_by).to eq("openai")
      expect(info.loaded).to be true
    end

    it "creates from symbol-keyed hash" do
      info = described_class.from_api({
                                        id: "gpt-4",
                                        object: "model",
                                        created: 1_686_935_002,
                                        owned_by: "openai",
                                        loaded: true
                                      })

      expect(info.id).to eq("gpt-4")
    end

    it "defaults object to 'model'" do
      info = described_class.from_api({ "id" => "gpt-4" })
      expect(info.object).to eq("model")
    end

    it "handles missing fields" do
      info = described_class.from_api({ "id" => "gpt-4" })

      expect(info.id).to eq("gpt-4")
      expect(info.created).to be_nil
      expect(info.owned_by).to be_nil
      expect(info.loaded).to be_nil
    end
  end

  describe "pattern matching" do
    it "supports deconstruct_keys" do
      info = described_class.new(
        id: "gpt-4", object: "model", created: nil, owned_by: nil, loaded: true
      )

      case info
      in { id:, loaded: true }
        expect(id).to eq("gpt-4")
      else
        raise "Pattern should match"
      end
    end
  end
end
