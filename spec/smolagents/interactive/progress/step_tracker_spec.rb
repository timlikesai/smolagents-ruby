require "spec_helper"

RSpec.describe Smolagents::Interactive::Progress::StepTracker do
  let(:output) { StringIO.new }
  let(:tracker) { described_class.new(max_steps: 10, output:) }

  describe "#initialize" do
    it "creates a tracker with default state" do
      expect(tracker.current_step).to eq 0
      expect(tracker.max_steps).to eq 10
      expect(tracker.completed_steps).to be_empty
    end
  end

  describe "#start_step" do
    it "updates the current step" do
      tracker.start_step(1, "Analyzing")
      expect(tracker.current_step).to eq 1
    end

    context "when output is a TTY" do # -- IO interface is stable
      let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

      it "outputs the step line" do
        tracker.start_step(1, "Analyzing")
        expect(output).to have_received(:print).with(/Step 1/)
      end
    end
  end

  describe "#complete_step" do
    it "records the completed step" do
      tracker.complete_step(1, :success)
      expect(tracker.completed_steps).to contain_exactly(hash_including(step: 1, outcome: :success))
    end

    context "when output is a TTY" do
      let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

      it "outputs the completion line with success icon" do
        tracker.complete_step(1, :success)
        expect(output).to have_received(:puts).with(/Step 1.*✓/)
      end

      it "outputs the completion line with error icon" do
        tracker.complete_step(1, :error)
        expect(output).to have_received(:puts).with(/Step 1.*!/)
      end
    end
  end

  describe "#progress_percentage" do
    it "calculates the correct percentage" do
      tracker.complete_step(1, :success)
      tracker.complete_step(2, :success)
      expect(tracker.progress_percentage).to eq 20
    end

    it "returns 0 when max_steps is zero" do
      zero_tracker = described_class.new(max_steps: 0, output:)
      expect(zero_tracker.progress_percentage).to eq 0
    end
  end

  describe "#reset" do
    it "resets the tracker state" do
      tracker.start_step(1, "First")
      tracker.complete_step(1, :success)
      tracker.reset

      expect(tracker.current_step).to eq 0
      expect(tracker.completed_steps).to be_empty
    end
  end

  describe "#update_description" do
    context "when output is a TTY" do
      let(:output) { double("tty_output", tty?: true, print: nil, flush: nil, puts: nil) }

      it "updates the step description" do
        tracker.start_step(1, "Initial")
        tracker.update_description("Updated")
        expect(output).to have_received(:print).with(/Updated/).at_least(:once)
      end
    end
  end
end
