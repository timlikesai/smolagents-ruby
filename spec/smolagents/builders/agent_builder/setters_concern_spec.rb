require "spec_helper"

RSpec.describe Smolagents::Builders::AgentSettersConcern do
  include_context "with mocked tools"
  include_context "with mocked model"

  let(:builder_class) { Smolagents::Builders::AgentBuilder }
  let(:builder) { builder_class.create }

  describe "#executor" do
    let(:executor) { instance_double(Smolagents::RactorExecutor) }

    it "sets the executor" do
      result = builder.executor(executor)

      expect(result.config[:executor]).to eq(executor)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.executor(executor)

      expect(result).not_to equal(builder)
    end
  end

  describe "#logger" do
    let(:logger) { Logger.new(nil) }

    it "sets the logger" do
      result = builder.logger(logger)

      expect(result.config[:logger]).to eq(logger)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.logger(logger)

      expect(result).not_to equal(builder)
    end
  end

  describe "#authorized_imports" do
    it "sets authorized imports" do
      result = builder.authorized_imports("json", "csv")

      expect(result.config[:authorized_imports]).to eq(%w[json csv])
    end

    it "flattens nested arrays" do
      result = builder.authorized_imports(%w[json csv], "net/http")

      expect(result.config[:authorized_imports]).to eq(%w[json csv net/http])
    end

    it "returns a new builder instance (immutability)" do
      result = builder.authorized_imports("json")

      expect(result).not_to equal(builder)
    end
  end

  describe "#max_steps" do
    it "sets max_steps", max_time: 0.1 do
      result = builder.max_steps(15)

      expect(result.config[:max_steps]).to eq(15)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.max_steps(10)

      expect(result).not_to equal(builder)
    end

    it "validates positive integer" do
      expect { builder.max_steps(0) }
        .to raise_error(ArgumentError)
    end

    it "validates max limit" do
      expect { builder.max_steps(Smolagents::Config::MAX_STEPS_LIMIT + 1) }
        .to raise_error(ArgumentError)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.max_steps(10) }
          .to raise_error(FrozenError)
      end
    end
  end

  describe "#instructions" do
    it "sets custom instructions" do
      result = builder.instructions("Be concise and accurate")

      expect(result.config[:custom_instructions]).to eq("Be concise and accurate")
    end

    it "accepts array of strings" do
      result = builder.instructions(["Be concise", "Be accurate"])

      expect(result.config[:custom_instructions]).to eq("Be concise\nBe accurate")
    end

    it "appends instructions on multiple calls" do
      result = builder
               .instructions("First instruction")
               .instructions("Second instruction")

      expect(result.config[:custom_instructions]).to eq("First instruction\n\nSecond instruction")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.instructions("Test")

      expect(result).not_to equal(builder)
    end

    it "validates non-empty string" do
      expect { builder.instructions("") }
        .to raise_error(ArgumentError)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.instructions("Test") }
          .to raise_error(FrozenError)
      end
    end
  end

  describe "#evaluation" do
    it "enables evaluation by default (no args)" do
      result = builder.evaluation

      expect(result.config[:evaluation_enabled]).to be(true)
    end

    it "enables evaluation with positional true" do
      result = builder.evaluation(true)

      expect(result.config[:evaluation_enabled]).to be(true)
    end

    it "disables evaluation with positional false" do
      result = builder.evaluation(false)

      expect(result.config[:evaluation_enabled]).to be(false)
    end

    it "enables evaluation with enabled: true" do
      result = builder.evaluation(enabled: true)

      expect(result.config[:evaluation_enabled]).to be(true)
    end

    it "disables evaluation with enabled: false" do
      result = builder.evaluation(enabled: false)

      expect(result.config[:evaluation_enabled]).to be(false)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.evaluation

      expect(result).not_to equal(builder)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.evaluation }
          .to raise_error(FrozenError)
      end
    end
  end

  describe "#observe" do
    it "defaults to :with_summary mode" do
      result = builder.observe

      expect(result.config[:observe_mode]).to eq(:with_summary)
    end

    it "accepts :structure_only mode" do
      result = builder.observe(:structure_only)

      expect(result.config[:observe_mode]).to eq(:structure_only)
    end

    it "accepts :with_summary mode" do
      result = builder.observe(:with_summary)

      expect(result.config[:observe_mode]).to eq(:with_summary)
    end

    it "accepts a block for summarizer model" do
      summarizer = instance_double(Smolagents::Models::Model)
      result = builder.observe(:with_summary) { summarizer }

      expect(result.config[:summarizer_model]).to eq(summarizer)
    end

    it "raises for invalid mode" do
      expect { builder.observe(:invalid_mode) }
        .to raise_error(ArgumentError, /Invalid observe mode/)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.observe

      expect(result).not_to equal(builder)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.observe }
          .to raise_error(FrozenError)
      end
    end
  end
end
