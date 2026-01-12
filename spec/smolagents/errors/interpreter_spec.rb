RSpec.describe Smolagents::InterpreterError do
  it "inherits from StandardError" do
    expect(described_class.superclass).to eq(StandardError)
  end

  it "can be raised with a message" do
    expect { raise described_class, "syntax error" }.to raise_error(described_class, "syntax error")
  end
end
