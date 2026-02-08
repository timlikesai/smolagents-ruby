require "spec_helper"

RSpec.describe Smolagents::Builders::RoutingConcern do
  let(:builder) { Smolagents::Builders::AgentBuilder.create }
  let(:mock_model) { build_mock_model }

  describe "#dispatcher" do
    it "accepts a block" do
      new_builder = builder.dispatcher { mock_model }

      expect(new_builder.configuration[:dispatcher_block]).to be_a(Proc)
    end

    it "accepts a model instance" do
      new_builder = builder.dispatcher(mock_model)

      expect(new_builder.configuration[:dispatcher_instance]).to eq(mock_model)
    end

    it "accepts a model ID string" do
      new_builder = builder.dispatcher("functiongemma-270m-it-mlx")

      expect(new_builder.configuration[:dispatcher_model_id]).to eq("functiongemma-270m-it-mlx")
    end

    it "raises without arguments" do
      expect { builder.dispatcher }.to raise_error(ArgumentError)
    end

    it "is immutable" do
      new_builder = builder.dispatcher(mock_model)

      expect(new_builder).not_to equal(builder)
      expect(builder.configuration[:dispatcher_instance]).to be_nil
    end
  end

  describe "#routing" do
    it "accepts :conservative preset" do
      new_builder = builder.routing(:conservative)

      expect(new_builder.configuration[:routing_preset]).to eq(:conservative)
    end

    it "accepts :aggressive preset" do
      new_builder = builder.routing(:aggressive)

      expect(new_builder.configuration[:routing_preset]).to eq(:aggressive)
    end

    it "accepts custom thresholds" do
      new_builder = builder.routing(high_threshold: 0.9, low_threshold: 0.6)

      expect(new_builder.configuration[:routing_high_threshold]).to eq(0.9)
      expect(new_builder.configuration[:routing_low_threshold]).to eq(0.6)
    end

    it "accepts collect_traces option" do
      new_builder = builder.routing(collect_traces: true)

      expect(new_builder.configuration[:routing_collect_traces]).to be true
    end

    it "raises for unknown preset" do
      expect { builder.routing(:unknown) }.to raise_error(ArgumentError)
    end
  end

  describe "#build_dispatcher_model" do
    context "with dispatcher instance" do
      let(:configured_builder) { builder.dispatcher(mock_model) }

      it "returns the instance" do
        model = configured_builder.build_dispatcher_model

        expect(model).to eq(mock_model)
      end
    end

    context "with dispatcher block" do
      let(:configured_builder) { builder.dispatcher { mock_model } }

      it "evaluates the block" do
        model = configured_builder.build_dispatcher_model

        expect(model).to eq(mock_model)
      end
    end

    context "without dispatcher" do
      it "returns nil" do
        expect(builder.build_dispatcher_model).to be_nil
      end
    end
  end

  describe "#build_router_config" do
    let(:dispatcher) do
      model = build_mock_model
      allow(model).to receive(:model_id).and_return("functiongemma-270m-it-mlx")
      model
    end

    context "with known model" do
      it "uses profile-based config" do
        config = builder.build_router_config(dispatcher)

        expect(config.model_id).to eq("functiongemma-270m-it-mlx")
        expect(config.high_confidence_threshold).to eq(0.85) # FunctionGemma profile
      end
    end

    context "with conservative preset" do
      let(:configured_builder) { builder.routing(:conservative) }

      it "uses conservative thresholds" do
        config = configured_builder.build_router_config(dispatcher)

        expect(config.high_confidence_threshold).to eq(0.9)
        expect(config.low_confidence_threshold).to eq(0.7)
      end
    end

    context "with custom thresholds" do
      let(:configured_builder) { builder.routing(high_threshold: 0.95, low_threshold: 0.65) }

      it "applies custom thresholds" do
        config = configured_builder.build_router_config(dispatcher)

        expect(config.high_confidence_threshold).to eq(0.95)
        expect(config.low_confidence_threshold).to eq(0.65)
      end
    end

    context "with trace collection" do
      let(:configured_builder) { builder.routing(collect_traces: true) }

      it "enables trace collection" do
        config = configured_builder.build_router_config(dispatcher)

        expect(config.collect_traces?).to be true
      end
    end

    context "without dispatcher" do
      it "returns nil" do
        expect(builder.build_router_config(nil)).to be_nil
      end
    end
  end

  describe "full chain" do
    it "supports complete configuration" do
      configured = builder
                   .model { mock_model }
                   .dispatcher("functiongemma-270m-it-mlx")
                   .routing(:aggressive)
                   .tools(:search)

      expect(configured.configuration[:dispatcher_model_id]).to eq("functiongemma-270m-it-mlx")
      expect(configured.configuration[:routing_preset]).to eq(:aggressive)
    end
  end
end
