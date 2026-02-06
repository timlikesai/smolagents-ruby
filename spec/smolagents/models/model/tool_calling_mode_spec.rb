RSpec.describe "Model tool_calling_mode" do
  describe Smolagents::Models::Model::Configuration do
    let(:model_class) do
      Class.new(Smolagents::Models::Model) do
        def generate(*) = nil
      end
    end

    it "defaults to :code" do
      model = model_class.new(model_id: "test")
      expect(model.tool_calling_mode).to eq(:code)
    end

    it "accepts :native" do
      model = model_class.new(model_id: "test", tool_calling_mode: :native)
      expect(model.tool_calling_mode).to eq(:native)
    end

    it "accepts :auto" do
      model = model_class.new(model_id: "test", tool_calling_mode: :auto)
      expect(model.tool_calling_mode).to eq(:auto)
    end

    it "falls back to :code for invalid values" do
      model = model_class.new(model_id: "test", tool_calling_mode: :invalid)
      expect(model.tool_calling_mode).to eq(:code)
    end
  end

  describe "OpenAIModel auto mode resolution" do
    let(:capabilities_with_tools) do
      Smolagents::Types::ServerCapability.from_server_type(Smolagents::Types::ServerTypes::LLAMA_CPP)
    end

    it "resolves :auto to :native when server supports tools" do
      model = Smolagents::Models::OpenAIModel.new(
        model_id: "test", api_key: "test", tool_calling_mode: :auto,
        server_capabilities: capabilities_with_tools, client: double("client")
      )
      expect(model.tool_calling_mode).to eq(:native)
    end

    it "resolves :auto to :code without capabilities" do
      model = Smolagents::Models::OpenAIModel.new(
        model_id: "test", api_key: "test", tool_calling_mode: :auto,
        client: double("client")
      )
      expect(model.tool_calling_mode).to eq(:code)
    end

    it "preserves :native without resolution" do
      model = Smolagents::Models::OpenAIModel.new(
        model_id: "test", api_key: "test", tool_calling_mode: :native,
        client: double("client")
      )
      expect(model.tool_calling_mode).to eq(:native)
    end
  end
end
