require "spec_helper"

RSpec.describe Smolagents::Builders::ModelConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#model" do
    context "with a block (lazy instantiation)" do
      it "stores the model block" do
        result = builder.model { mock_model }

        expect(result.config[:model_block]).to be_a(Proc)
      end

      it "defers model creation" do
        call_count = 0
        result = builder.model do
          call_count += 1
          mock_model
        end

        expect(call_count).to eq(0)
        result.config[:model_block].call
        expect(call_count).to eq(1)
      end

      it "returns the model when block is called" do
        result = builder.model { mock_model }

        expect(result.config[:model_block].call).to eq(mock_model)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.model { mock_model }

        expect(result).not_to equal(builder)
        expect(result).to be_a(builder_class)
      end

      it "does not mutate the original builder" do
        builder.model { mock_model }

        expect(builder.config[:model_block]).to be_nil
      end
    end

    context "with a direct instance (eager)" do
      it "wraps instance in a proc" do
        result = builder.model(mock_model)

        expect(result.config[:model_block]).to be_a(Proc)
      end

      it "returns the same instance on each call" do
        result = builder.model(mock_model)
        block = result.config[:model_block]

        expect(block.call).to equal(mock_model)
        expect(block.call).to equal(mock_model)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.model(mock_model)

        expect(result).not_to equal(builder)
      end
    end

    context "with a symbol (registered model)" do
      before do
        Smolagents.configure do |c|
          c.models do |m|
            m = m.register(:test_model, -> { mock_model })
            m
          end
        end
      end

      after { Smolagents.reset_configuration! }

      it "stores a proc that resolves the registered model" do
        result = builder.model(:test_model)

        expect(result.config[:model_block]).to be_a(Proc)
      end

      it "defers model lookup to call time" do
        result = builder.model(:test_model)

        expect(result.config[:model_block].call).to eq(mock_model)
      end
    end

    context "with no argument or block" do
      it "raises ArgumentError" do
        expect { builder.model }
          .to raise_error(ArgumentError, /Model required/)
      end
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.model { mock_model } }
          .to raise_error(FrozenError)
      end
    end
  end
end
