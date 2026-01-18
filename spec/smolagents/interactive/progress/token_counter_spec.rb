require "spec_helper"

RSpec.describe Smolagents::Interactive::Progress::TokenCounter do
  let(:output) { StringIO.new }
  let(:counter) { described_class.new(output:) }

  describe "#initialize" do
    it "creates a counter with zero tokens" do
      expect(counter.input_tokens).to eq 0
      expect(counter.output_tokens).to eq 0
    end
  end

  describe "#add" do
    it "accumulates input tokens" do
      counter.add(input: 100)
      counter.add(input: 50)
      expect(counter.input_tokens).to eq 150
    end

    it "accumulates output tokens" do
      counter.add(output: 50)
      counter.add(output: 25)
      expect(counter.output_tokens).to eq 75
    end

    it "handles both input and output" do
      counter.add(input: 100, output: 50)
      expect(counter.input_tokens).to eq 100
      expect(counter.output_tokens).to eq 50
    end
  end

  describe "#total_tokens" do
    it "returns the sum of input and output" do
      counter.add(input: 100, output: 50)
      expect(counter.total_tokens).to eq 150
    end
  end

  describe "#estimated_cost" do
    it "calculates cost based on token counts" do
      counter.add(input: 1000, output: 500)
      # Default: 0.0001 per 1K input, 0.0002 per 1K output
      # = 0.0001 + 0.0001 = 0.0002
      expect(counter.estimated_cost).to be_within(0.0001).of(0.0002)
    end
  end

  describe "#summary_line" do
    it "formats the token summary" do
      counter.add(input: 1234, output: 567)
      line = counter.summary_line
      expect(line).to include("1,234")
      expect(line).to include("567")
      expect(line).to include("in")
      expect(line).to include("out")
    end
  end

  describe "#display" do
    context "when output is not a TTY" do
      it "does not output anything" do
        counter.add(input: 100)
        counter.display
        expect(output.string).to be_empty
      end
    end

    context "when output is a TTY" do # -- IO interface is stable
      let(:output) { double("tty_output", tty?: true, puts: nil) }

      it "outputs the summary when tokens are present" do
        counter.add(input: 100)
        counter.display
        expect(output).to have_received(:puts)
      end
    end

    it "does not output when no tokens" do
      tty_output = double("tty_output", tty?: true, puts: nil)

      empty_counter = described_class.new(output: tty_output)
      empty_counter.display
      expect(tty_output).not_to have_received(:puts)
    end
  end

  describe "#reset" do
    it "resets the token counts" do
      counter.add(input: 100, output: 50)
      counter.reset

      expect(counter.input_tokens).to eq 0
      expect(counter.output_tokens).to eq 0
    end
  end
end
