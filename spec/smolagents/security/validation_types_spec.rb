require "spec_helper"

RSpec.describe Smolagents::Security do
  describe "ValidationResult" do
    describe ".success" do
      subject(:result) { Smolagents::Security::ValidationResult.success }

      it "creates a valid result" do
        expect(result.valid?).to be true
      end

      it "returns true for valid?" do
        expect(result).to be_valid
      end

      it "returns false for invalid?" do
        expect(result).not_to be_invalid
      end

      it "has empty violations" do
        expect(result.violations).to be_empty
      end

      it "violations are frozen" do
        expect(result.violations).to be_frozen
      end

      it "to_error_message returns nil" do
        expect(result.to_error_message).to be_nil
      end
    end

    describe ".failure" do
      subject(:result) do
        violations = [
          Smolagents::Security::ValidationViolation.dangerous_method("eval"),
          Smolagents::Security::ValidationViolation.dangerous_constant("File")
        ]
        Smolagents::Security::ValidationResult.failure(violations:)
      end

      it "creates an invalid result" do
        expect(result.valid?).to be false
      end

      it "returns true for invalid?" do
        expect(result).to be_invalid
      end

      it "returns false for valid?" do
        expect(result).not_to be_valid
      end

      it "contains violations" do
        expect(result.violations.size).to eq(2)
      end

      it "violations are frozen" do
        expect(result.violations).to be_frozen
      end

      it "to_error_message includes header" do
        expect(result.to_error_message).to include("Code validation failed:")
      end

      it "to_error_message includes violation details" do
        message = result.to_error_message
        expect(message).to include("eval")
        expect(message).to include("File")
      end

      it "accepts single violation" do
        violation = Smolagents::Security::ValidationViolation.dangerous_method("system")
        single_result = Smolagents::Security::ValidationResult.failure(violations: violation)
        expect(single_result.violations.size).to eq(1)
      end

      it "converts single violation to array" do
        violation = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        result = Smolagents::Security::ValidationResult.failure(violations: violation)
        expect(result.violations).to be_an(Array)
      end

      it "formats each violation with bullet" do
        violations = [
          Smolagents::Security::ValidationViolation.dangerous_method("eval"),
          Smolagents::Security::ValidationViolation.backtick_execution
        ]
        result = Smolagents::Security::ValidationResult.failure(violations:)
        message = result.to_error_message
        expect(message.scan("  - ").count).to eq(2)
      end
    end

    describe "immutability" do
      it "is immutable (Data.define)" do
        result = Smolagents::Security::ValidationResult.success
        expect { result.valid = false }.to raise_error(NoMethodError)
      end

      it "prevents mutation of violations" do
        violation = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        result = Smolagents::Security::ValidationResult.failure(violations: violation)
        new_violation = Smolagents::Security::ValidationViolation.dangerous_method("system")
        expect { result.violations << new_violation }.to raise_error(FrozenError)
      end
    end

    describe "pattern matching" do
      it "supports deconstruct_keys for success" do
        result = Smolagents::Security::ValidationResult.success
        matched = case result
                  in { valid: true, violations: [] }
                    true
                  else
                    false
                  end
        expect(matched).to be true
      end

      it "supports deconstruct_keys for failure" do
        violation = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        result = Smolagents::Security::ValidationResult.failure(violations: violation)
        matched = case result
                  in { valid: false, violations: violations } if violations.any?
                    true
                  else
                    false
                  end
        expect(matched).to be true
      end
    end
  end

  describe "ValidationViolation" do
    describe "factory methods" do
      describe ".dangerous_method" do
        it "creates a dangerous_method violation" do
          v = Smolagents::Security::ValidationViolation.dangerous_method("eval")
          expect(v.type).to eq(:dangerous_method)
          expect(v.detail).to eq("eval")
        end

        it "accepts context parameter" do
          v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end

        it "defaults context to nil" do
          v = Smolagents::Security::ValidationViolation.dangerous_method("eval")
          expect(v.context).to be_nil
        end
      end

      describe ".dangerous_constant" do
        it "creates a dangerous_constant violation" do
          v = Smolagents::Security::ValidationViolation.dangerous_constant("File")
          expect(v.type).to eq(:dangerous_constant)
          expect(v.detail).to eq("File")
        end

        it "accepts context parameter" do
          v = Smolagents::Security::ValidationViolation.dangerous_constant("ENV", context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end
      end

      describe ".backtick_execution" do
        it "creates a backtick_execution violation" do
          v = Smolagents::Security::ValidationViolation.backtick_execution
          expect(v.type).to eq(:backtick_execution)
          expect(v.detail).to eq("command execution")
        end

        it "accepts context parameter" do
          v = Smolagents::Security::ValidationViolation.backtick_execution(context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end
      end

      describe ".dangerous_pattern" do
        it "creates a dangerous_pattern violation" do
          v = Smolagents::Security::ValidationViolation.dangerous_pattern("`ls`")
          expect(v.type).to eq(:dangerous_pattern)
          expect(v.detail).to eq("`ls`")
        end

        it "accepts context parameter" do
          v = Smolagents::Security::ValidationViolation.dangerous_pattern("%x[cmd]", context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end
      end

      describe ".dangerous_import" do
        it "creates a dangerous_import violation" do
          v = Smolagents::Security::ValidationViolation.dangerous_import("net/http")
          expect(v.type).to eq(:dangerous_import)
          expect(v.detail).to eq("net/http")
        end

        it "accepts context parameter" do
          v = Smolagents::Security::ValidationViolation.dangerous_import("socket", context: :interpolation)
          expect(v.context).to eq(:interpolation)
        end
      end

      describe ".syntax_error" do
        it "creates a syntax_error violation" do
          v = Smolagents::Security::ValidationViolation.syntax_error("unexpected end")
          expect(v.type).to eq(:syntax_error)
          expect(v.detail).to eq("unexpected end")
        end

        it "context is always nil" do
          v = Smolagents::Security::ValidationViolation.syntax_error("error")
          expect(v.context).to be_nil
        end
      end
    end

    describe "#in_interpolation?" do
      it "returns true when context is :interpolation" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :interpolation)
        expect(v.in_interpolation?).to be true
      end

      it "returns false when context is nil" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        expect(v.in_interpolation?).to be false
      end

      it "returns false for other contexts" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :other)
        expect(v.in_interpolation?).to be false
      end
    end

    describe "#to_s" do
      it "formats dangerous_method" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        expect(v.to_s).to eq("Dangerous method call: eval")
      end

      it "formats dangerous_constant" do
        v = Smolagents::Security::ValidationViolation.dangerous_constant("File")
        expect(v.to_s).to eq("Dangerous constant access: File")
      end

      it "formats backtick_execution without detail" do
        v = Smolagents::Security::ValidationViolation.backtick_execution
        expect(v.to_s).to eq("Backtick command execution")
      end

      it "formats dangerous_pattern" do
        v = Smolagents::Security::ValidationViolation.dangerous_pattern("`ls`")
        expect(v.to_s).to eq("Dangerous pattern: `ls`")
      end

      it "formats dangerous_import" do
        v = Smolagents::Security::ValidationViolation.dangerous_import("net/http")
        expect(v.to_s).to eq("Dangerous import: net/http")
      end

      it "formats syntax_error" do
        v = Smolagents::Security::ValidationViolation.syntax_error("unexpected end")
        expect(v.to_s).to eq("Syntax error: unexpected end")
      end

      it "adds interpolation context suffix" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :interpolation)
        expect(v.to_s).to eq("Dangerous method call: eval (in string interpolation)")
      end

      it "interpolation suffix only for :interpolation context" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :other)
        expect(v.to_s).not_to include("(in string interpolation)")
      end
    end

    describe "immutability" do
      it "is immutable (Data.define)" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval")
        expect { v.type = :other }.to raise_error(NoMethodError)
      end
    end

    describe "pattern matching" do
      it "supports deconstruct_keys" do
        v = Smolagents::Security::ValidationViolation.dangerous_method("eval", context: :interpolation)
        matched = case v
                  in { type: :dangerous_method, detail: "eval", context: :interpolation }
                    true
                  else
                    false
                  end
        expect(matched).to be true
      end
    end
  end

  describe "NodeContext" do
    describe ".root" do
      subject(:context) { Smolagents::Security::NodeContext.root }

      it "creates root context" do
        expect(context.in_interpolation).to be false
        expect(context.depth).to eq(0)
      end

      it "context_type is nil" do
        expect(context.context_type).to be_nil
      end
    end

    describe "#enter_interpolation" do
      it "creates interpolation context" do
        root = Smolagents::Security::NodeContext.root
        interp = root.enter_interpolation
        expect(interp.in_interpolation).to be true
      end

      it "increments depth" do
        root = Smolagents::Security::NodeContext.root
        interp = root.enter_interpolation
        expect(interp.depth).to eq(1)
      end

      it "context_type is :interpolation" do
        root = Smolagents::Security::NodeContext.root
        interp = root.enter_interpolation
        expect(interp.context_type).to eq(:interpolation)
      end

      it "does not mutate original" do
        root = Smolagents::Security::NodeContext.root
        root.enter_interpolation
        expect(root.in_interpolation).to be false
        expect(root.depth).to eq(0)
      end
    end

    describe "#descend" do
      it "increments depth" do
        root = Smolagents::Security::NodeContext.root
        descended = root.descend
        expect(descended.depth).to eq(1)
      end

      it "preserves interpolation state" do
        root = Smolagents::Security::NodeContext.root
        descended = root.descend
        expect(descended.in_interpolation).to eq(root.in_interpolation)
      end

      it "can descend multiple levels" do
        root = Smolagents::Security::NodeContext.root
        deep = root.descend.descend.descend
        expect(deep.depth).to eq(3)
      end

      it "context_type matches state" do
        root = Smolagents::Security::NodeContext.root
        descended = root.descend
        expect(descended.context_type).to be_nil
      end
    end

    describe "immutability" do
      it "is immutable (Data.define)" do
        context = Smolagents::Security::NodeContext.root
        expect { context.depth = 5 }.to raise_error(NoMethodError)
      end
    end

    describe "pattern matching" do
      it "supports deconstruct_keys" do
        context = Smolagents::Security::NodeContext.root
        matched = case context
                  in { in_interpolation: false, depth: 0 }
                    true
                  else
                    false
                  end
        expect(matched).to be true
      end
    end
  end

  describe "VIOLATION_TYPES constant" do
    it "is an array of symbols" do
      types = Smolagents::Security::VIOLATION_TYPES
      expect(types).to be_an(Array)
      expect(types).to all(be_a(Symbol))
    end

    it "includes expected violation types" do
      types = Smolagents::Security::VIOLATION_TYPES
      expected = %i[dangerous_method dangerous_constant backtick_execution
                    dangerous_pattern dangerous_import syntax_error]
      expect(types).to match_array(expected)
    end

    it "is frozen" do
      expect(Smolagents::Security::VIOLATION_TYPES).to be_frozen
    end
  end

  describe "VIOLATION_MESSAGES constant" do
    it "is a hash" do
      expect(Smolagents::Security::VIOLATION_MESSAGES).to be_a(Hash)
    end

    it "has messages for all violation types" do
      Smolagents::Security::VIOLATION_TYPES.each do |type|
        expect(Smolagents::Security::VIOLATION_MESSAGES).to have_key(type)
      end
    end

    it "all messages are strings" do
      Smolagents::Security::VIOLATION_MESSAGES.each_value do |message|
        expect(message).to be_a(String)
      end
    end

    it "is frozen" do
      expect(Smolagents::Security::VIOLATION_MESSAGES).to be_frozen
    end
  end
end
