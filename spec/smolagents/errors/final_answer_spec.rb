# frozen_string_literal: true

RSpec.describe Smolagents::FinalAnswerException do
  it "inherits from StandardError" do
    expect(described_class.superclass).to eq(StandardError)
  end

  it "stores the value" do
    exception = described_class.new("the answer")
    expect(exception.value).to eq("the answer")
  end

  it "includes value in the message" do
    exception = described_class.new("42")
    expect(exception.message).to include("42")
  end

  it "can be rescued as StandardError" do
    result = nil
    begin
      raise described_class.new("test")
    rescue StandardError => e
      result = e.value
    end
    expect(result).to eq("test")
  end
end
