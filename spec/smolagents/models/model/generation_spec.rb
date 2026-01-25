require "smolagents/models/model"

RSpec.describe Smolagents::Models::Model::Generation do
  let(:model) { Smolagents::Model.new(model_id: "test-model") }
  let(:messages) { [Smolagents::ChatMessage.user("Hello")] }

  describe "#generate" do
    it "raises NotImplementedError on base class" do
      expect do
        model.generate(messages)
      end.to raise_error(NotImplementedError, /generate must be implemented/)
    end

    it "includes class name in error message" do
      expect do
        model.generate(messages)
      end.to raise_error(NotImplementedError, /Smolagents::Models::Model#generate/)
    end

    it "accepts stop_sequences parameter" do
      expect do
        model.generate(messages, stop_sequences: ["stop"])
      end.to raise_error(NotImplementedError)
    end

    it "accepts response_format parameter" do
      expect do
        model.generate(messages, response_format: { type: "json_object" })
      end.to raise_error(NotImplementedError)
    end

    it "accepts tools_to_call_from parameter" do
      tool = double(name: "search", description: "Search")
      expect do
        model.generate(messages, tools_to_call_from: [tool])
      end.to raise_error(NotImplementedError)
    end

    it "accepts additional kwargs" do
      expect do
        model.generate(messages, temperature: 0.5, max_tokens: 100, custom: "value")
      end.to raise_error(NotImplementedError)
    end
  end

  describe "#generate_stream" do
    context "without block" do
      it "returns an Enumerator" do
        result = model.generate_stream(messages)
        expect(result).to be_a(Enumerator)
      end

      it "returns lazy evaluation" do
        enum = model.generate_stream(messages)
        expect(enum.lazy).to be_a(Enumerator::Lazy)
      end

      it "can be chained with Enumerator methods" do
        enum = model.generate_stream(messages)
        expect(enum).to respond_to(:each)
        expect(enum).to respond_to(:map)
        expect(enum).to respond_to(:take)
      end
    end

    context "with block" do
      it "raises NotImplementedError" do
        expect do
          model.generate_stream(messages) { |chunk| chunk }
        end.to raise_error(NotImplementedError, /generate_stream must be implemented/)
      end

      it "includes class name in error message" do
        expect do
          model.generate_stream(messages) { |chunk| chunk }
        end.to raise_error(NotImplementedError, /Smolagents::Models::Model#generate_stream/)
      end
    end

    it "passes messages to implementation" do
      allow(model).to receive(:generate_stream).and_call_original

      model.generate_stream(messages)

      expect(model).to have_received(:generate_stream).with(messages)
    end

    it "forwards kwargs to implementation" do
      allow(model).to receive(:generate_stream).and_call_original

      model.generate_stream(messages, temperature: 0.5)

      expect(model).to have_received(:generate_stream).with(messages, temperature: 0.5)
    end
  end
end
