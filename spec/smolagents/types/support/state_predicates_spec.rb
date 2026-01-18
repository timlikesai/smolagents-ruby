RSpec.describe Smolagents::Types::TypeSupport::StatePredicates do
  # Test types for specs
  ResultWithState = Data.define(:state, :value) do
    include Smolagents::Types::TypeSupport::StatePredicates

    state_predicates success: :success,
                     error: :error,
                     pending: :pending
  end

  ResultWithStatus = Data.define(:status, :answer) do
    include Smolagents::Types::TypeSupport::StatePredicates

    state_predicates :status,
                     achieved: :goal_achieved,
                     stuck: :stuck
  end

  ResultWithGroups = Data.define(:state, :output) do
    include Smolagents::Types::TypeSupport::StatePredicates

    state_predicates success: :success,
                     terminal: %i[success error timeout],
                     retriable: %i[partial max_steps]
  end

  describe "single state predicates" do
    context "with default :state field" do
      let(:success) { ResultWithState.new(state: :success, value: "ok") }
      let(:error) { ResultWithState.new(state: :error, value: nil) }

      it "generates predicate methods" do
        expect(success).to respond_to(:success?)
        expect(success).to respond_to(:error?)
        expect(success).to respond_to(:pending?)
      end

      it "returns true when state matches" do
        expect(success.success?).to be true
        expect(error.error?).to be true
      end

      it "returns false when state does not match" do
        expect(success.error?).to be false
        expect(error.success?).to be false
      end
    end

    context "with custom field name" do
      let(:achieved) { ResultWithStatus.new(status: :goal_achieved, answer: "42") }
      let(:stuck) { ResultWithStatus.new(status: :stuck, answer: nil) }

      it "generates predicate methods" do
        expect(achieved).to respond_to(:achieved?)
        expect(achieved).to respond_to(:stuck?)
      end

      it "checks against the correct field" do
        expect(achieved.achieved?).to be true
        expect(achieved.stuck?).to be false
        expect(stuck.stuck?).to be true
      end
    end
  end

  describe "group predicates (arrays)" do
    let(:success) { ResultWithGroups.new(state: :success, output: "done") }
    let(:partial) { ResultWithGroups.new(state: :partial, output: nil) }
    let(:unknown) { ResultWithGroups.new(state: :unknown, output: nil) }

    it "returns true when state is in the group" do
      expect(success.terminal?).to be true
      expect(partial.retriable?).to be true
    end

    it "returns false when state is not in the group" do
      expect(success.retriable?).to be false
      expect(partial.terminal?).to be false
    end

    it "handles unknown states" do
      expect(unknown.terminal?).to be false
      expect(unknown.retriable?).to be false
    end
  end

  describe "mixed single and group predicates" do
    let(:success) { ResultWithGroups.new(state: :success, output: "done") }

    it "supports both types together" do
      expect(success.success?).to be true
      expect(success.terminal?).to be true
    end
  end
end
