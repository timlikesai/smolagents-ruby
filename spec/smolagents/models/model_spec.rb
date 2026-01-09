# frozen_string_literal: true

RSpec.describe Smolagents::Model do
  describe "#initialize" do
    it "sets model_id" do
      model = described_class.new(model_id: "test-model")
      expect(model.model_id).to eq("test-model")
    end

    it "accepts additional kwargs" do
      model = described_class.new(model_id: "test", temperature: 0.5)
      expect(model.model_id).to eq("test")
    end
  end

  describe "#generate" do
    it "raises NotImplementedError" do
      model = described_class.new(model_id: "test")
      expect do
        model.generate([])
      end.to raise_error(NotImplementedError, /generate must be implemented/)
    end
  end

  describe "#generate_stream" do
    it "returns an enumerator when no block given" do
      model = described_class.new(model_id: "test")
      result = model.generate_stream([])
      expect(result).to be_a(Enumerator)
    end

    it "raises NotImplementedError when called with block" do
      model = described_class.new(model_id: "test")
      expect do
        model.generate_stream([]) { |chunk| chunk }
      end.to raise_error(NotImplementedError, /generate_stream must be implemented/)
    end
  end

  describe "#call" do
    it "delegates to generate" do
      model = described_class.new(model_id: "test")
      expect(model).to receive(:generate).with([], foo: :bar)
      model.call([], foo: :bar)
    end
  end

  describe "#parse_tool_calls" do
    it "returns the message unchanged by default" do
      model = described_class.new(model_id: "test")
      message = Smolagents::ChatMessage.user("test")
      expect(model.parse_tool_calls(message)).to eq(message)
    end
  end

  describe "#validate_required_params" do
    it "does not raise when all required params present" do
      model = described_class.new(model_id: "test")
      expect do
        model.validate_required_params(%i[foo bar], { foo: 1, bar: 2, baz: 3 })
      end.not_to raise_error
    end

    it "raises when required params missing" do
      model = described_class.new(model_id: "test")
      expect do
        model.validate_required_params(%i[foo bar], { foo: 1 })
      end.to raise_error(ArgumentError, /Missing required parameters: bar/)
    end
  end

  describe "#logger" do
    it "returns nil by default" do
      model = described_class.new(model_id: "test")
      expect(model.logger).to be_nil
    end

    it "returns logger after setting" do
      model = described_class.new(model_id: "test")
      logger = Logger.new($stdout)
      model.logger = logger
      expect(model.logger).to eq(logger)
    end
  end
end
