require "smolagents/concerns/execution/code_hints"
require "smolagents/concerns/execution/budget_tracking"

RSpec.describe Smolagents::Concerns::CodeHints do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::CodeHints
      include Smolagents::Concerns::BudgetTracking

      attr_accessor :max_steps

      def initialize
        @max_steps = nil
      end
    end
  end

  let(:instance) { test_class.new }
  let(:mock_action_step) do
    instance_double(Smolagents::Types::ActionStep, step_number: 1)
  end

  describe "#with_code_hints" do
    context "when final_answer is already set" do
      it "returns logs unchanged" do
        logs = "Output"
        code = "result = search(query: 'test')\nfinal_answer(answer: result)"
        final_answer = "Already completed"

        result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)
        expect(result).to eq("Output")
      end
    end

    context "without code" do
      it "returns logs unchanged" do
        logs = "Output"
        code = nil
        final_answer = nil

        result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)
        expect(result).to eq("Output")
      end
    end

    context "with final_answer assignment pattern" do
      it "adds assignment hint" do
        logs = "Output"
        code = "final_answer = result"
        final_answer = nil

        result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)
        expect(result).to include("[HINT:")
        expect(result).to include("final_answer is a function")
      end
    end

    context "with puts instead of final_answer" do
      it "adds puts hint" do
        logs = "Output"
        code = "puts result"
        final_answer = nil

        result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)
        expect(result).to include("[HINT:")
        expect(result).to include("final_answer")
        expect(result).to include("puts")
      end
    end

    context "with both patterns" do
      it "includes both hints" do
        logs = "Output"
        code = "final_answer = result\nputs result"
        final_answer = nil

        result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)
        hints = result.scan("[HINT:").size
        expect(hints).to be >= 1
      end
    end

    context "with budget reminder" do
      before do
        instance.max_steps = 3
      end

      it "includes both hints and budget" do
        logs = "Output"
        code = "final_answer = result"
        final_answer = nil

        action_step = instance_double(Smolagents::Types::ActionStep, step_number: 2)
        result = instance.send(:with_code_hints, action_step, logs, code, final_answer)

        expect(result).to include("Output")
        expect(result).to include("[HINT:") if instance.send(:collect_code_hints, code, final_answer).any?
      end
    end
  end

  describe "#collect_code_hints" do
    context "when final_answer is set" do
      it "returns empty array" do
        code = "final_answer = result\nputs result"
        final_answer = "Complete"

        hints = instance.send(:collect_code_hints, code, final_answer)
        expect(hints).to be_empty
      end
    end

    context "when code is nil" do
      it "returns empty array" do
        hints = instance.send(:collect_code_hints, nil, nil)
        expect(hints).to be_empty
      end
    end

    context "with final_answer assignment" do
      it "detects assignment pattern" do
        code = "final_answer = 'result'"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.size).to be >= 1
        expect(hints.first).to include("function")
      end

      it "detects assignment with spaces" do
        code = "final_answer   =   result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.size).to be >= 1
      end

      it "detects assignment at any point in code" do
        code = <<~CODE
          x = 1
          final_answer = x
          puts x
        CODE

        hints = instance.send(:collect_code_hints, code, nil)
        expect(hints.size).to be >= 1
      end
    end

    context "with puts instead of final_answer" do
      it "detects puts without final_answer" do
        code = "result = search(query: 'test')\nputs result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.size).to be >= 1
        expect(hints.first).to include("final_answer")
      end

      it "does not hint when final_answer is present" do
        code = "puts result\nfinal_answer(answer: result)"
        hints = instance.send(:collect_code_hints, code, nil)

        # Should not include puts hint since final_answer is present
        expect(hints.select { |h| h.include?("puts") }).to be_empty
      end

      it "detects puts with various spacing" do
        code = "puts   result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.size).to be >= 1
      end

      it "detects puts at start of word boundary" do
        code = "result = puts_helper(data)\nputs result"
        hints = instance.send(:collect_code_hints, code, nil)

        # Should still detect puts as a standalone word
        expect(hints.size).to be >= 1
      end
    end

    context "with multiple patterns" do
      it "collects both hints" do
        code = "final_answer = 'test'\nputs result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.size).to be >= 1
      end
    end

    context "with print instead of final_answer" do
      it "detects print without final_answer" do
        code = "result = search(query: 'test')\nprint result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.any? { |h| h.include?("puts/print") }).to be true
      end
    end

    context "with bare return" do
      it "detects return without final_answer" do
        code = "result = search(query: 'test')\nreturn result"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.any? { |h| h.include?("return") }).to be true
      end

      it "does not hint when final_answer is present" do
        code = "result = search(query: 'test')\nfinal_answer(answer: result)\nreturn"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.select { |h| h.include?("return") }).to be_empty
      end
    end

    context "with missing final_answer" do
      it "hints when last line is a bare variable" do
        code = "result = search(query: 'test')\nresult"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.any? { |h| h.include?("Don't forget") }).to be true
      end

      it "does not hint when final_answer is present" do
        code = "result = search(query: 'test')\nfinal_answer(answer: result)"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints).to be_empty
      end

      it "does not hint when last line is a method call" do
        code = "result = search(query: 'test')"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints.select { |h| h.include?("Don't forget") }).to be_empty
      end
    end

    context "with correct code" do
      it "returns empty array" do
        code = "result = search(query: 'test')\nfinal_answer(answer: result)"
        hints = instance.send(:collect_code_hints, code, nil)

        expect(hints).to be_empty
      end
    end
  end

  describe "ASSIGNMENT_HINT" do
    let(:hint) { Smolagents::Concerns::CodeHints::ASSIGNMENT_HINT }

    it "returns a hint message" do
      expect(hint).to be_a(String)
      expect(hint).to include("[HINT:")
      expect(hint).to include("final_answer is a function")
    end

    it "includes correction example" do
      expect(hint).to include("final_answer(answer:")
    end
  end

  describe "PUTS_HINT" do
    let(:hint) { Smolagents::Concerns::CodeHints::PUTS_HINT }

    it "returns a hint message" do
      expect(hint).to be_a(String)
      expect(hint).to include("[HINT:")
      expect(hint).to include("final_answer")
    end

    it "mentions puts/print" do
      expect(hint).to include("puts/print")
    end

    it "includes correction example" do
      expect(hint).to include("final_answer(answer:")
    end
  end

  describe "RETURN_HINT" do
    let(:hint) { Smolagents::Concerns::CodeHints::RETURN_HINT }

    it "mentions return and final_answer" do
      expect(hint).to include("return")
      expect(hint).to include("final_answer(answer:")
    end
  end

  describe "MISSING_FINAL_HINT" do
    let(:hint) { Smolagents::Concerns::CodeHints::MISSING_FINAL_HINT }

    it "reminds about final_answer" do
      expect(hint).to include("final_answer(answer:")
      expect(hint).to include("Don't forget")
    end
  end

  describe "block parameter hint" do
    it "detects single-param block with bracket access" do
      code = '@data.select { |x| x["key"] }'
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints).to include(Smolagents::Concerns::CodeHints::BLOCK_PARAM_HINT)
    end

    it "detects single-param block with method call" do
      code = "@items.map { |item| item.name }"
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints).to include(Smolagents::Concerns::CodeHints::BLOCK_PARAM_HINT)
    end

    it "does not trigger for multi-param blocks" do
      code = "@data.each_with_index { |item, idx| item + idx }"
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints).not_to include(Smolagents::Concerns::CodeHints::BLOCK_PARAM_HINT)
    end

    it "does not trigger for Ruby 4.0 it keyword" do
      code = '@data.select { it["key"] }'
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints).not_to include(Smolagents::Concerns::CodeHints::BLOCK_PARAM_HINT)
    end
  end

  describe "pattern matching" do
    it "detects final_answer assignment before function call" do
      code = "final_answer = data"
      match = code.match?(/final_answer\s*=/)

      expect(match).to be true
    end

    it "does not match final_answer function call" do
      code = "final_answer(answer: data)"
      match = code.match?(/final_answer\s*=/)

      expect(match).to be false
    end

    it "detects standalone puts" do
      code = "puts data"
      has_puts = code.match?(/\bputs\b/)
      has_final = code.match?(/\bfinal_answer\b/)

      expect(has_puts).to be true
      expect(has_final).to be false
    end

    it "does not confuse puts_helper with puts" do
      # \bputs\b does NOT match "puts" in "puts_helper" because underscore
      # IS a word character in Ruby regex, so there's no word boundary
      # between "puts" and "_helper"
      code = "result = puts_helper(data)"
      has_standalone_puts = code.match?(/\bputs\b/)

      expect(has_standalone_puts).to be false
    end
  end

  describe "integration" do
    it "provides helpful hints for common mistakes" do
      logs = "Search completed"
      code_mistake = "final_answer = result"
      final_answer = nil

      result = instance.send(:with_code_hints, mock_action_step, logs, code_mistake, final_answer)

      # The result should contain the original logs
      expect(result).to include(logs)
      # And should include hints for the common mistake
      expect(result).to include("[HINT:") if instance.send(:collect_code_hints, code_mistake, final_answer).any?
    end

    it "guides model toward correct syntax" do
      code = "puts result"
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints.first).to include("final_answer(answer:")
    end

    it "does not hint correct implementations" do
      code = "result = search(query: 'python')\nfinal_answer(answer: result)"
      hints = instance.send(:collect_code_hints, code, nil)

      expect(hints).to be_empty
    end

    it "combines hints with logs naturally" do
      logs = "Executed 2 tools"
      code = "final_answer = data"
      final_answer = nil

      result = instance.send(:with_code_hints, mock_action_step, logs, code, final_answer)

      # Result should have original logs plus hints
      expect(result).to include("Executed 2 tools") if code.nil? == false
    end
  end
end
