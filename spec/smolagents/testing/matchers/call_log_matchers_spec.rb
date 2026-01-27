RSpec.describe Smolagents::Testing::Matchers::CallLogMatchers do
  include Smolagents::Testing::Matchers

  let(:log) { Smolagents::Testing::CallLog.new }

  let(:search_entry) do
    Smolagents::Testing::CallLogEntry.new(
      type: :tool_call, name: :search, args: { query: "Ruby" },
      result: "Found", timestamp: Time.now, metadata: {}
    )
  end

  let(:fetch_entry) do
    Smolagents::Testing::CallLogEntry.new(
      type: :tool_call, name: :fetch, args: { url: "https://example.com" },
      result: "Content", timestamp: Time.now, metadata: {}
    )
  end

  let(:step_entry) do
    Smolagents::Testing::CallLogEntry.new(
      type: :step, name: :step1, args: { step_number: 1 },
      result: "Done", timestamp: Time.now, metadata: { outcome: :success }
    )
  end

  before do
    log.instance_variable_get(:@entries).push(search_entry, fetch_entry, step_entry)
  end

  describe "have_called_tool" do
    it "matches when tool was called" do
      expect(log).to have_called_tool(:search)
    end

    it "fails when tool was not called" do
      expect(log).not_to have_called_tool(:missing)
    end

    describe ".with" do
      it "matches with exact args" do
        expect(log).to have_called_tool(:search).with(query: "Ruby")
      end

      it "fails with wrong args" do
        expect(log).not_to have_called_tool(:search).with(query: "Python")
      end

      it "matches with regex" do
        expect(log).to have_called_tool(:search).with(query: /Ru/)
      end
    end

    describe ".times" do
      it "matches exact call count" do
        log.instance_variable_get(:@entries).push(search_entry)
        expect(log).to have_called_tool(:search).times(2)
      end

      it "fails with wrong count" do
        expect(log).not_to have_called_tool(:search).times(5)
      end
    end
  end

  describe "have_completed_step" do
    it "matches when step completed" do
      expect(log).to have_completed_step(1)
    end

    it "fails when step not found" do
      expect(log).not_to have_completed_step(99)
    end

    describe ".with_outcome" do
      it "matches with correct outcome" do
        expect(log).to have_completed_step(1).with_outcome(:success)
      end

      it "fails with wrong outcome" do
        expect(log).not_to have_completed_step(1).with_outcome(:error)
      end
    end
  end

  describe "have_logged_steps" do
    it "matches correct step count" do
      expect(log).to have_logged_steps(1)
    end

    it "fails with wrong step count" do
      expect(log).not_to have_logged_steps(5)
    end
  end

  describe "have_entry" do
    it "matches tool pattern" do
      expect(log).to have_entry(tool: :search)
    end

    it "matches tool with args" do
      expect(log).to have_entry(tool: :search, args: { query: "Ruby" })
    end

    it "matches step pattern" do
      expect(log).to have_entry(step: 1)
    end

    it "fails when no match" do
      expect(log).not_to have_entry(tool: :missing)
    end
  end

  describe "have_called_tools_in_order" do
    it "matches correct order" do
      expect(log).to have_called_tools_in_order(:search, :fetch)
    end

    it "matches partial order" do
      expect(log).to have_called_tools_in_order(:search)
    end

    it "fails with wrong order" do
      expect(log).not_to have_called_tools_in_order(:fetch, :search)
    end

    it "fails when tool missing" do
      expect(log).not_to have_called_tools_in_order(:search, :missing)
    end
  end
end
