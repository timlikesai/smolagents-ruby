RSpec.describe Smolagents::Agents::Agent do
  let(:mock_model) { instance_double(Smolagents::Model, model_id: "test-model") }

  it "is the base class for all agents" do
    expect(described_class.included_modules).to include(Smolagents::Concerns::ReActLoop)
    expect(described_class.included_modules).to include(Smolagents::Concerns::StepExecution)
    expect(described_class.included_modules).to include(Smolagents::Concerns::Planning)
    expect(described_class.included_modules).to include(Smolagents::Concerns::ManagedAgents)
  end

  it "requires subclasses to implement system_prompt" do
    subclass = Class.new(described_class)
    agent = subclass.allocate
    expect { agent.system_prompt }.to raise_error(NotImplementedError)
  end

  it "requires subclasses to implement execute_step" do
    subclass = Class.new(described_class)
    agent = subclass.allocate
    expect { agent.execute_step(nil) }.to raise_error(NotImplementedError)
  end
end
