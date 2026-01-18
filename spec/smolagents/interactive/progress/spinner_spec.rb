require "spec_helper"

RSpec.describe Smolagents::Interactive::Progress::Spinner do
  let(:output) { StringIO.new }
  let(:spinner) { described_class.new(output:) }

  describe "#initialize" do
    it "creates a spinner with default state" do
      expect(spinner.running?).to be false
    end
  end

  describe "#start" do
    context "when output is not a TTY" do
      it "does not start" do
        spinner.start("Loading")
        expect(spinner.running?).to be false
      end
    end

    context "when output is a TTY" do # -- IO interface is stable
      let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

      it "starts the spinner" do
        spinner.start("Loading")
        expect(spinner.running?).to be true
        spinner.stop
      end

      it "does not start if already running" do
        spinner.start("First")
        spinner.start("Second")
        expect(spinner.running?).to be true
        spinner.stop
      end
    end
  end

  describe "#stop" do
    let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

    it "stops a running spinner" do
      spinner.start("Loading")
      expect(spinner.running?).to be true
      spinner.stop
      expect(spinner.running?).to be false
    end

    it "is safe to call when not running" do
      expect { spinner.stop }.not_to raise_error
    end
  end

  describe "#succeed" do
    let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

    it "stops the spinner and shows success" do
      spinner.start("Loading")
      spinner.succeed("Done!")
      expect(spinner.running?).to be false
      expect(output).to have_received(:puts).with(/Done!/)
    end
  end

  describe "#fail" do
    let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

    it "stops the spinner and shows failure" do
      spinner.start("Loading")
      spinner.fail("Error!")
      expect(spinner.running?).to be false
      expect(output).to have_received(:puts).with(/Error!/)
    end
  end

  describe "#update" do
    it "updates the message without raising" do
      expect { spinner.update("New message") }.not_to raise_error
    end
  end
end
