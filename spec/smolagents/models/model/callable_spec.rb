require "smolagents/models/model"

RSpec.describe Smolagents::Models::Model::Callable do
  let(:model) { Smolagents::Model.new(model_id: "test-model") }

  describe "#call" do
    it "delegates to #generate with positional arguments" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      allow(model).to receive(:generate).and_call_original

      expect do
        model.call(messages)
      end.to raise_error(NotImplementedError)

      expect(model).to have_received(:generate).with(messages)
    end

    it "delegates to #generate with keyword arguments" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      allow(model).to receive(:generate).and_call_original

      expect do
        model.call(messages, stop_sequences: ["stop"])
      end.to raise_error(NotImplementedError)

      expect(model).to have_received(:generate).with(messages, stop_sequences: ["stop"])
    end

    it "delegates to #generate with mixed arguments" do
      messages = [Smolagents::ChatMessage.user("Hello")]
      allow(model).to receive(:generate).and_call_original

      expect do
        model.call(messages, temperature: 0.5, max_tokens: 100)
      end.to raise_error(NotImplementedError)

      expect(model).to have_received(:generate).with(messages, temperature: 0.5, max_tokens: 100)
    end
  end
end
