RSpec.describe "MessageFormatter native tool response handling" do
  let(:formatter_class) do
    Class.new do
      include Smolagents::Models::OpenAI::MessageFormatter

      public :format_message, :map_role, :native_tool_response?
    end
  end

  let(:formatter) { formatter_class.new }

  describe "#map_role" do
    it "maps tool_response to 'tool' when tool_call_id is present" do
      msg = Smolagents::Types::ChatMessage.tool_response("result", tool_call_id: "call_1")
      expect(formatter.map_role(:tool_response, msg)).to eq("tool")
    end

    it "maps tool_response to 'user' when no tool_call_id" do
      msg = Smolagents::Types::ChatMessage.tool_response("observation")
      expect(formatter.map_role(:tool_response, msg)).to eq("user")
    end

    it "maps tool_call to 'assistant'" do
      expect(formatter.map_role(:tool_call)).to eq("assistant")
    end

    it "passes through standard roles" do
      expect(formatter.map_role(:system)).to eq("system")
      expect(formatter.map_role(:user)).to eq("user")
      expect(formatter.map_role(:assistant)).to eq("assistant")
    end
  end

  describe "#format_message" do
    it "includes tool_call_id for native tool responses" do
      msg = Smolagents::Types::ChatMessage.tool_response("42", tool_call_id: "call_1")
      formatted = formatter.format_message(msg)

      expect(formatted[:role]).to eq("tool")
      expect(formatted[:tool_call_id]).to eq("call_1")
      expect(formatted[:content]).to eq("42")
    end

    it "omits tool_call_id for code mode observations" do
      msg = Smolagents::Types::ChatMessage.tool_response("Observation: result")
      formatted = formatter.format_message(msg)

      expect(formatted[:role]).to eq("user")
      expect(formatted).not_to have_key(:tool_call_id)
    end
  end
end
