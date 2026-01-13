RSpec.describe "Builder Base Features" do
  describe "ModelBuilder with core features" do
    let(:builder) { Smolagents.model(:openai) }

    describe ".help" do
      it "shows available methods" do
        help_text = builder.help

        expect(help_text).to include("ModelBuilder - Available Methods")
        expect(help_text).to include("Required:")
        expect(help_text).to include(".id")
        expect(help_text).to include("Optional:")
        expect(help_text).to include(".temperature")
        expect(help_text).to include(".api_key")
        expect(help_text).to include("Current Configuration:")
        expect(help_text).to include("Pattern Matching:")
        expect(help_text).to include("Build:")
      end

      it "shows method descriptions" do
        help_text = builder.help

        expect(help_text).to include("Set the model identifier")
        expect(help_text).to include("Set temperature (0.0-2.0")
        expect(help_text).to include("Set API authentication key")
      end

      it "shows aliases" do
        help_text = builder.help

        expect(help_text).to include("aliases: temp")
        expect(help_text).to include("aliases: tokens")
        expect(help_text).to include("aliases: key")
      end
    end

    describe "validation" do
      it "validates id must be non-empty string" do
        expect { builder.id("") }.to raise_error(ArgumentError, /Invalid value for id/)
        expect { builder.id(123) }.to raise_error(ArgumentError, /Invalid value for id/)
      end

      it "validates temperature range" do
        expect { builder.temperature(-0.1) }.to raise_error(ArgumentError, /Invalid value for temperature/)
        expect { builder.temperature(2.1) }.to raise_error(ArgumentError, /Invalid value for temperature/)

        expect { builder.temperature(0.0) }.not_to raise_error
        expect { builder.temperature(1.0) }.not_to raise_error
        expect { builder.temperature(2.0) }.not_to raise_error
      end

      it "validates max_tokens range" do
        expect { builder.max_tokens(0) }.to raise_error(ArgumentError, /Invalid value for max_tokens/)
        expect { builder.max_tokens(-10) }.to raise_error(ArgumentError, /Invalid value for max_tokens/)
        expect { builder.max_tokens(100_001) }.to raise_error(ArgumentError, /Invalid value for max_tokens/)

        expect { builder.max_tokens(1) }.not_to raise_error
        expect { builder.max_tokens(4000) }.not_to raise_error
        expect { builder.max_tokens(100_000) }.not_to raise_error
      end

      it "validates timeout range" do
        expect { builder.timeout(0) }.to raise_error(ArgumentError, /Invalid value for timeout/)
        expect { builder.timeout(-5) }.to raise_error(ArgumentError, /Invalid value for timeout/)
        expect { builder.timeout(601) }.to raise_error(ArgumentError, /Invalid value for timeout/)

        expect { builder.timeout(1) }.not_to raise_error
        expect { builder.timeout(30) }.not_to raise_error
        expect { builder.timeout(600) }.not_to raise_error
      end

      it "validates api_key is non-empty string" do
        expect { builder.api_key("") }.to raise_error(ArgumentError, /Invalid value for api_key/)
        expect { builder.api_key(nil) }.to raise_error(ArgumentError, /Invalid value for api_key/)
      end

      it "includes helpful error messages" do
        expect { builder.temperature(5.0) }.to raise_error(ArgumentError) do |error|
          expect(error.message).to include("Set temperature (0.0-2.0")
        end
      end
    end

    describe ".freeze!" do
      it "returns a frozen builder" do
        frozen = builder.id("gpt-4").freeze!

        expect(frozen.frozen_config?).to be true
      end

      it "prevents further modifications" do
        frozen = builder.id("gpt-4").api_key("key").freeze!

        expect { frozen.temperature(0.5) }.to raise_error(FrozenError, /Cannot modify frozen/)
        expect { frozen.max_tokens(1000) }.to raise_error(FrozenError, /Cannot modify frozen/)
        expect { frozen.timeout(30) }.to raise_error(FrozenError, /Cannot modify frozen/)
      end

      it "preserves configuration before freezing" do
        frozen = builder.id("gpt-4").api_key("key").temperature(0.7).freeze!

        expect(frozen.config[:model_id]).to eq("gpt-4")
        expect(frozen.config[:api_key]).to eq("key")
        expect(frozen.config[:temperature]).to eq(0.7)
      end

      it "can still build frozen configuration" do
        frozen = builder.id("gpt-4").api_key("test-key").freeze!

        model = frozen.build

        expect(model).to be_a(Smolagents::OpenAIModel)
        expect(model.model_id).to eq("gpt-4")
      end

      it "does not affect unfrozen builders" do
        unfrozen = builder.id("gpt-4")
        unfrozen.freeze!

        # Original builder is not frozen
        expect(unfrozen.frozen_config?).to be false

        # Can still modify original
        expect { unfrozen.temperature(0.5) }.not_to raise_error
      end
    end

    describe "convenience aliases" do
      it "supports .temp for .temperature" do
        builder_with_temp = builder.temp(0.7)

        expect(builder_with_temp.config[:temperature]).to eq(0.7)
      end

      it "supports .tokens for .max_tokens" do
        builder_with_tokens = builder.tokens(4000)

        expect(builder_with_tokens.config[:max_tokens]).to eq(4000)
      end

      it "supports .key for .api_key" do
        builder_with_key = builder.key("test-key")

        expect(builder_with_key.config[:api_key]).to eq("test-key")
      end

      it "validates through aliases" do
        expect { builder.temp(5.0) }.to raise_error(ArgumentError, /Invalid value for temperature/)
        expect { builder.tokens(-10) }.to raise_error(ArgumentError, /Invalid value for max_tokens/)
      end
    end

    describe "immutability and chaining" do
      it "returns new builder instances" do
        builder1 = Smolagents.model(:openai)
        builder2 = builder1.id("gpt-4")
        builder3 = builder2.temperature(0.7)

        expect(builder1.config[:model_id]).to be_nil
        expect(builder2.config[:model_id]).to eq("gpt-4")
        expect(builder2.config[:temperature]).to be_nil
        expect(builder3.config[:temperature]).to eq(0.7)
      end

      it "supports method chaining" do
        final_builder = Smolagents.model(:openai)
                                  .id("gpt-4")
                                  .key("test-key")
                                  .temp(0.7)
                                  .tokens(4000)
                                  .timeout(30)

        expect(final_builder.config[:model_id]).to eq("gpt-4")
        expect(final_builder.config[:api_key]).to eq("test-key")
        expect(final_builder.config[:temperature]).to eq(0.7)
        expect(final_builder.config[:max_tokens]).to eq(4000)
        expect(final_builder.config[:timeout]).to eq(30)
      end
    end
  end

  describe "pattern matching with Data.define" do
    it "supports pattern matching on ModelBuilder" do
      builder = Smolagents.model(:openai).id("gpt-4").temperature(0.7)

      result = case builder
               in Smolagents::Builders::ModelBuilder[type_or_model: :openai, configuration: { model_id:, temperature: }]
                 "OpenAI #{model_id} at temp #{temperature}"
               else
                 "no match"
               end

      expect(result).to eq("OpenAI gpt-4 at temp 0.7")
    end

    it "supports destructuring configuration" do
      builder = Smolagents.model(:openai)
                          .id("claude-3-opus")
                          .temperature(0.5)
                          .max_tokens(8000)

      case builder
      in Smolagents::Builders::ModelBuilder[configuration: { model_id:, temperature:, max_tokens: }]
        expect(model_id).to eq("claude-3-opus")
        expect(temperature).to eq(0.5)
        expect(max_tokens).to eq(8000)
      end
    end
  end
end
