RSpec.describe Smolagents::InterpreterError do
  it "inherits from ExecutorError" do
    expect(described_class.superclass).to eq(Smolagents::ExecutorError)
  end

  it "can be raised with a message" do
    expect { raise described_class, "syntax error" }.to raise_error(described_class, "syntax error")
  end
end
