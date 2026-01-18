# Shared examples for tool specs.
# Tools are composable actions that agents can invoke.

# Validates that a tool has proper metadata configuration.
# Requires `tool` to be defined in the including spec.
RSpec.shared_examples "a valid tool" do
  it "has a non-nil name" do
    expect(tool.name).not_to be_nil
    expect(tool.name).to be_a(String)
    expect(tool.name).not_to be_empty
  end

  it "has a description" do
    expect(tool.description).not_to be_nil
    expect(tool.description).to be_a(String)
    expect(tool.description.length).to be >= 10
  end

  it "has inputs as a Hash" do
    expect(tool.inputs).to be_a(Hash)
  end

  it "has a valid output_type" do
    expect(tool.output_type).to be_a(String)
    expect(Smolagents::Tool::AUTHORIZED_TYPES).to include(tool.output_type)
  end

  it "has input schemas with required keys" do
    tool.inputs.each do |name, schema|
      expect(schema).to be_a(Hash), "Input '#{name}' must be a Hash"
      expect(schema).to have_key(:type), "Input '#{name}' must have :type"
      expect(schema).to have_key(:description), "Input '#{name}' must have :description"
    end
  end

  describe "#to_h" do
    it "returns a hash with tool metadata" do
      hash = tool.to_h
      expect(hash).to be_a(Hash)
      expect(hash).to have_key(:name)
      expect(hash).to have_key(:description)
      expect(hash).to have_key(:inputs)
      expect(hash).to have_key(:output_type)
    end
  end

  describe "#format_for(:code)" do
    it "generates a code prompt string" do
      prompt = tool.format_for(:code)
      expect(prompt).to be_a(String)
      expect(prompt).to include(tool.name)
    end
  end

  describe "#format_for(:tool_calling)" do
    it "generates a tool calling prompt string" do
      prompt = tool.format_for(:tool_calling)
      expect(prompt).to be_a(String)
      expect(prompt).to include(tool.name)
    end
  end
end

# Validates that a tool can be executed properly.
# Requires:
#   - `tool` to be defined in the including spec
#   - `valid_args` Hash of valid arguments for execute
#   - (optional) `expected_result_type` - expected class/type of result (defaults to any)
RSpec.shared_examples "an executable tool" do
  it "responds to #execute" do
    expect(tool).to respond_to(:execute)
  end

  it "responds to #call" do
    expect(tool).to respond_to(:call)
  end

  describe "#call" do
    it "wraps result in ToolResult by default" do
      result = tool.call(**valid_args)
      expect(result).to be_a(Smolagents::ToolResult)
    end

    it "includes tool name in ToolResult metadata" do
      result = tool.call(**valid_args)
      expect(result.tool_name).to eq(tool.name)
    end

    it "can skip wrapping with wrap_result: false" do
      result = tool.call(**valid_args, wrap_result: false)
      expect(result).not_to be_a(Smolagents::ToolResult)
    end
  end
end

# Validates tool input validation behavior.
# Requires:
#   - `tool` with at least one required input
#   - `valid_args` Hash of valid arguments
#   - `required_input_name` Symbol of a required input field
RSpec.shared_examples "a tool with input validation" do
  describe "#validate_tool_arguments" do
    it "accepts valid arguments" do
      expect { tool.validate_tool_arguments(valid_args) }.not_to raise_error
    end

    it "rejects missing required arguments" do
      invalid_args = valid_args.reject { |k, _| k == required_input_name }
      expect do
        tool.validate_tool_arguments(invalid_args)
      end.to raise_error(Smolagents::AgentToolCallError, /missing required input/)
    end

    it "rejects unexpected arguments" do
      args_with_extra = valid_args.merge(unexpected_arg: "value")
      expect do
        tool.validate_tool_arguments(args_with_extra)
      end.to raise_error(Smolagents::AgentToolCallError, /unexpected input/)
    end
  end
end
