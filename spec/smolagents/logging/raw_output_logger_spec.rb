require "spec_helper"
require "smolagents/logging/raw_output_logger"
require "tmpdir"
require "json"

RSpec.describe Smolagents::Logging::RawOutputLogger do
  let(:tmpdir) { Dir.mktmpdir("raw_output_logger_test") }
  let(:fixed_time) { Time.new(2026, 1, 16, 12, 30, 45) }

  after { FileUtils.rm_rf(tmpdir) }

  describe "#initialize" do
    it "creates the directory if it does not exist" do
      new_dir = File.join(tmpdir, "nested", "logs")
      expect(Dir.exist?(new_dir)).to be false

      logger = described_class.new(directory: new_dir, timestamp: fixed_time)
      logger.close

      expect(Dir.exist?(new_dir)).to be true
    end

    it "creates a timestamped log file" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.close

      expect(logger.filepath).to eq(File.join(tmpdir, "20260116-123045_raw_outputs.log"))
      expect(File.exist?(logger.filepath)).to be true
    end

    it "starts with zero entry count" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      expect(logger.entry_count).to eq(0)
      logger.close
    end

    it "is open after initialization" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      expect(logger.open?).to be true
      logger.close
    end
  end

  describe "#log_run" do
    it "writes run data to file" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_run(model_id: "test-model", config: "baseline", data: { task: "test", output: 42 })
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("MODEL: test-model | CONFIG: baseline")
      expect(content).to include('"task":"test"')
      expect(content).to include('"output":42')
    end

    it "increments entry count" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_run(model_id: "m1", config: "c1", data: {})
      logger.log_run(model_id: "m2", config: "c2", data: {})
      expect(logger.entry_count).to eq(2)
      logger.close
    end

    it "returns self for chaining" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      result = logger.log_run(model_id: "m", config: "c", data: {})
      expect(result).to be(logger)
      logger.close
    end

    it "raises when logger is closed" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.close

      expect { logger.log_run(model_id: "m", config: "c", data: {}) }
        .to raise_error("Logger is closed")
    end

    it "flushes immediately (sync mode)" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_run(model_id: "test", config: "test", data: { value: "immediate" })

      # Read file while still open - data should be there
      content = File.read(logger.filepath)
      expect(content).to include("immediate")
      logger.close
    end
  end

  describe "#log_error" do
    it "writes exception details" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      error = RuntimeError.new("Something broke")
      error.set_backtrace(["line1.rb:10", "line2.rb:20"])

      logger.log_error(model_id: "test-model", error:)
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("ERROR: test-model")
      expect(content).to include("RuntimeError")
      expect(content).to include("Something broke")
      expect(content).to include("line1.rb:10")
    end

    it "writes string errors" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_error(model_id: "test", error: "simple error message")
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("simple error message")
    end

    it "includes context" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_error(model_id: "test", error: "err", context: { step: 3, task: "calc" })
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include('"step":3')
      expect(content).to include('"task":"calc"')
    end

    it "increments entry count" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_error(model_id: "m", error: "e")
      expect(logger.entry_count).to eq(1)
      logger.close
    end
  end

  describe "#log_step" do
    it "writes step data with raw output" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_step(
        model_id: "gpt-4",
        step_number: 2,
        raw_output: "Thought: I need to calculate.\n```ruby\nresult = 2 + 2\n```",
        parsed_code: "result = 2 + 2"
      )
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("STEP: gpt-4 #2")
      expect(content).to include("I need to calculate")
      expect(content).to include("result = 2 + 2")
    end

    it "writes parse errors" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_step(
        model_id: "model",
        step_number: 1,
        raw_output: "malformed output without code",
        parse_error: "No code block found"
      )
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("No code block found")
      expect(content).to include("malformed output without code")
    end

    it "increments entry count" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_step(model_id: "m", step_number: 1, raw_output: "out")
      expect(logger.entry_count).to eq(1)
      logger.close
    end
  end

  describe "#close" do
    it "closes the file" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      expect(logger.open?).to be true
      logger.close
      expect(logger.open?).to be false
    end

    it "can be called multiple times safely" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.close
      expect { logger.close }.not_to raise_error
    end
  end

  describe ".open" do
    it "yields an open logger" do
      described_class.open(directory: tmpdir) do |logger|
        expect(logger.open?).to be true
        logger.log_run(model_id: "test", config: "test", data: { foo: "bar" })
      end
    end

    it "closes logger after block" do
      logger_ref = nil
      described_class.open(directory: tmpdir) do |logger|
        logger_ref = logger
      end
      expect(logger_ref.open?).to be false
    end

    it "closes logger even on exception" do
      logger_ref = nil
      expect do
        described_class.open(directory: tmpdir) do |logger|
          logger_ref = logger
          raise "boom"
        end
      end.to raise_error("boom")
      expect(logger_ref.open?).to be false
    end

    it "creates file with logged data" do
      filepath = nil
      described_class.open(directory: tmpdir) do |logger|
        filepath = logger.filepath
        logger.log_run(model_id: "m", config: "c", data: { x: 1 })
      end

      content = File.read(filepath)
      expect(content).to include('"x":1')
    end
  end

  describe "data integrity" do
    it "preserves complex nested data" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      complex_data = {
        task: "multi-step calculation",
        steps: [
          { step: 1, output: "Thought: First step\n```ruby\nx = 1\n```", result: 1 },
          { step: 2, output: "Thought: Second step\n```ruby\ny = x + 1\n```", result: 2 }
        ],
        final_output: 2,
        metadata: { tokens: 150, duration: 1.5 }
      }
      logger.log_run(model_id: "test", config: "test", data: complex_data)
      logger.close

      # Parse the JSON from the file
      content = File.read(logger.filepath)
      json_line = content.lines.find { |l| l.start_with?("{") }
      parsed = JSON.parse(json_line)

      expect(parsed["steps"].length).to eq(2)
      expect(parsed["steps"][0]["step"]).to eq(1)
      expect(parsed["final_output"]).to eq(2)
      expect(parsed["metadata"]["tokens"]).to eq(150)
    end

    it "handles special characters in output" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      special_output = "Line1\nLine2\tTabbed\r\nWindows line\0Null byte\"Quotes\\"
      logger.log_step(model_id: "test", step_number: 1, raw_output: special_output)
      logger.close

      content = File.read(logger.filepath)
      json_line = content.lines.find { |l| l.start_with?("{") }
      parsed = JSON.parse(json_line)
      expect(parsed["raw_output"]).to include("Line1")
      expect(parsed["raw_output"]).to include("Tabbed")
    end

    it "handles unicode" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_run(model_id: "test", config: "test", data: { message: "Hello" })
      logger.close

      content = File.read(logger.filepath)
      expect(content).to include("Hello")
    end
  end

  describe "multiple entries" do
    it "writes multiple entries in order" do
      logger = described_class.new(directory: tmpdir, timestamp: fixed_time)
      logger.log_run(model_id: "m1", config: "c1", data: { order: 1 })
      logger.log_error(model_id: "m1", error: "err")
      logger.log_step(model_id: "m1", step_number: 1, raw_output: "out")
      logger.log_run(model_id: "m2", config: "c2", data: { order: 2 })
      logger.close

      content = File.read(logger.filepath)
      lines = content.lines

      # Find positions of each entry
      m1_pos = lines.index { |l| l.include?("MODEL: m1") }
      err_pos = lines.index { |l| l.include?("ERROR: m1") }
      step_pos = lines.index { |l| l.include?("STEP: m1") }
      m2_pos = lines.index { |l| l.include?("MODEL: m2") }

      expect(m1_pos).to be < err_pos
      expect(err_pos).to be < step_pos
      expect(step_pos).to be < m2_pos
    end
  end
end
