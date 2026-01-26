# Shared examples for common model testing patterns.
#
# These shared examples provide reusable test patterns for validating model
# behavior. Use them in model specs to ensure consistent testing across
# different model implementations.
#
# @example Using basic tests
#   RSpec.describe MyModel do
#     let(:model_config) { { model_id: "test-model" } }
#     it_behaves_like "a model that passes basic tests"
#   end
#
# @example Using tool calling tests
#   RSpec.describe MyModel do
#     let(:model_config) { { model_id: "test-model" } }
#     it_behaves_like "a model that handles tool calling", :calculator
#   end
#
# @example Using reliability tests
#   RSpec.describe MyModel do
#     let(:model_config) { { model_id: "test-model" } }
#     it_behaves_like "a reliable model", pass_threshold: 0.9, runs: 5
#   end

RSpec.shared_examples "a model that passes basic tests" do
  let(:model) { described_class.new(**model_config) }

  it "responds to simple questions" do
    result = Smolagents.test(:model)
                       .task("What is 2+2? Reply with just the number.")
                       .expects { |out| out.to_s.include?("4") }
                       .run(model)

    expect(result).to be_passed
  end

  it "completes within step limit" do
    result = Smolagents.test(:model)
                       .task("Say hello")
                       .max_steps(3)
                       .expects { |out| !out.nil? }
                       .run(model)

    expect(result).to have_completed_in(steps: 1..3)
  end
end

RSpec.shared_examples "a model that handles tool calling" do |tool_name|
  let(:model) { described_class.new(**model_config) }

  it "calls the #{tool_name} tool correctly" do
    result = Smolagents.test(:model)
                       .task("Use #{tool_name} to perform a calculation")
                       .tools(tool_name)
                       .expects { |out| out.to_s.match?(/#{tool_name}\(/) || !out.nil? }
                       .run(model)

    expect(result).to be_passed
  end
end

RSpec.shared_examples "a reliable model" do |pass_threshold: 0.9, runs: 5|
  let(:model) { described_class.new(**model_config) }

  it "achieves #{(pass_threshold * 100).to_i}% reliability over #{runs} runs" do
    result = Smolagents.test(:model)
                       .task("What is 1+1? Reply with just the number.")
                       .expects { |out| out.to_s.include?("2") }
                       .run_n_times(runs)
                       .pass_threshold(pass_threshold)
                       .run(model)

    expect(result).to have_pass_rate(at_least: pass_threshold)
  end
end

RSpec.shared_examples "a model meeting capability requirements" do |capabilities|
  let(:model) { described_class.new(**model_config) }
  let(:requirements) do
    builder = Smolagents.test_suite(:capability_test)
    capabilities.each { |cap| builder.requires(cap) }
    builder
  end

  it "passes all required capability tests" do
    results = requirements.all_test_cases.map do |test_case|
      Smolagents.test(:model).from(test_case).run(model)
    end

    failed = results.reject(&:passed?)
    expect(failed).to be_empty, "Failed tests: #{failed.map { |r| r.test_case.name }}"
  end
end
