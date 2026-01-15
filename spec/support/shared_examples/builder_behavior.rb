# Shared examples for builder specs.
# Builders follow a consistent pattern: immutable, chainable, validating.

RSpec.shared_examples "an immutable builder" do
  it "returns new instance on modification" do
    modified = builder.public_send(method_name, *method_args)
    expect(modified).not_to equal(builder)
    expect(modified).to be_a(described_class)
  end

  it "does not mutate original builder" do
    original_config = builder.config.dup
    builder.public_send(method_name, *method_args)
    expect(builder.config).to eq(original_config)
  end
end

RSpec.shared_examples "a builder configuration method" do |method:, config_key:, value:, expected: nil|
  let(:method_name) { method }
  let(:method_args) { [value].flatten }
  let(:expected_value) { expected || value }

  it "sets #{config_key} in configuration" do
    result = builder.public_send(method, *method_args)
    expect(result.config[config_key]).to eq(expected_value)
  end

  it_behaves_like "an immutable builder"
end

RSpec.shared_examples "a builder with validation" do |method:, invalid_values:|
  invalid_values.each do |invalid_value, error_pattern|
    it "rejects invalid #{method} value: #{invalid_value.inspect}" do
      expect { builder.public_send(method, invalid_value) }.to raise_error(ArgumentError, error_pattern)
    end
  end
end

RSpec.shared_examples "a builder with freeze support" do
  describe "#freeze!" do
    it "returns frozen builder" do
      frozen = builder.freeze!
      expect(frozen).to be_frozen
    end

    it "raises on modification after freeze" do
      frozen = builder.freeze!
      expect { frozen.public_send(method_name, *method_args) }.to raise_error(FrozenError)
    end
  end
end

RSpec.shared_examples "a chainable builder" do
  it "supports method chaining" do
    result = chain_methods.reduce(builder) { |b, (method, args)| b.public_send(method, *args) }
    expect(result).to be_a(described_class)
  end
end

# Shared context for mocking tools registry
RSpec.shared_context "with mocked tools" do
  let(:mock_search_tool) do
    Smolagents::Tools.define_tool(
      "test_search",
      description: "Search for something",
      inputs: { "query" => { type: "string", description: "Query" } },
      output_type: "string"
    ) { |query:| "Results for #{query}" }
  end

  let(:mock_final_answer_tool) { Smolagents::Tools::FinalAnswerTool.new }

  before do
    allow(Smolagents::Tools).to receive(:get).and_call_original
    allow(Smolagents::Tools).to receive(:get).with("google_search").and_return(mock_search_tool)
    allow(Smolagents::Tools).to receive(:get).with("web_search").and_return(mock_search_tool)
    allow(Smolagents::Tools).to receive(:get).with("final_answer").and_return(mock_final_answer_tool)
    allow(Smolagents::Tools).to receive(:names).and_return(%w[google_search web_search final_answer])
  end
end

# Shared context for mocking models
RSpec.shared_context "with mocked model" do
  let(:mock_model) do
    instance_double(
      Smolagents::Models::Model,
      generate: Smolagents::Types::ChatMessage.new(role: "assistant", content: "test response"),
      model_id: "test-model"
    )
  end
end
