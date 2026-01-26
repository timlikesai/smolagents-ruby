RSpec.describe Smolagents::Builders::Support::FlexibleInput do
  let(:test_class) do
    Class.new do
      include Smolagents::Builders::Support::FlexibleInput

      # Expose private methods for testing
      public :resolve_boolean, :dispatch_by_type, :normalize_to_string,
             :resolve_toggle, :resolve_value_or_toggle
    end
  end

  let(:instance) { test_class.new }

  describe "#resolve_boolean" do
    it "returns keyword when provided" do
      expect(instance.resolve_boolean(:_default_, true, default: false)).to be true
      expect(instance.resolve_boolean(true, false, default: true)).to be false
    end

    it "returns default when UNSET" do
      expect(instance.resolve_boolean(:_default_, nil, default: true)).to be true
      expect(instance.resolve_boolean(:_default_, nil, default: false)).to be false
    end

    it "returns positional boolean directly" do
      expect(instance.resolve_boolean(true, nil, default: false)).to be true
      expect(instance.resolve_boolean(false, nil, default: true)).to be false
    end

    it "raises for invalid positional" do
      expect { instance.resolve_boolean("invalid", nil, default: true, name: "test") }
        .to raise_error(ArgumentError, %r{Invalid test.*Use true/false})
    end
  end

  describe "#dispatch_by_type" do
    it "returns keyword values when UNSET" do
      result = instance.dispatch_by_type(:_default_, Integer => 100, Symbol => :mask)
      expect(result).to eq([100, :mask])
    end

    it "dispatches Integer to matching slot" do
      result = instance.dispatch_by_type(500, Integer => nil, Symbol => :strategy)
      expect(result).to eq([500, :strategy])
    end

    it "dispatches Symbol to matching slot" do
      result = instance.dispatch_by_type(:full, Integer => 100, Symbol => nil)
      expect(result).to eq([100, :full])
    end

    it "raises for unmatched type" do
      expect { instance.dispatch_by_type("string", name: "test", Integer => nil, Symbol => nil) }
        .to raise_error(ArgumentError, /Invalid test.*Use Integer, Symbol/)
    end
  end

  describe "#normalize_to_string" do
    it "joins arrays with newlines by default" do
      expect(instance.normalize_to_string(%w[a b c])).to eq("a\nb\nc")
    end

    it "accepts custom separator" do
      expect(instance.normalize_to_string(%w[a b], separator: ", ")).to eq("a, b")
    end

    it "converts non-arrays to string" do
      expect(instance.normalize_to_string(123)).to eq("123")
      expect(instance.normalize_to_string(:symbol)).to eq("symbol")
    end

    it "passes strings through" do
      expect(instance.normalize_to_string("hello")).to eq("hello")
    end
  end

  describe "#resolve_toggle" do
    it "returns keyword when provided" do
      expect(instance.resolve_toggle(:_default_, true, default: false)).to be true
    end

    it "returns default when UNSET" do
      expect(instance.resolve_toggle(:_default_, nil, default: true)).to be true
    end

    it "accepts boolean positionals" do
      expect(instance.resolve_toggle(true, nil, default: false)).to be true
      expect(instance.resolve_toggle(false, nil, default: true)).to be false
    end

    it "accepts symbol aliases for enabled" do
      expect(instance.resolve_toggle(:enabled, nil, default: false)).to be true
      expect(instance.resolve_toggle(:on, nil, default: false)).to be true
    end

    it "accepts symbol aliases for disabled" do
      expect(instance.resolve_toggle(:disabled, nil, default: true)).to be false
      expect(instance.resolve_toggle(:off, nil, default: true)).to be false
    end

    it "raises for invalid positional" do
      expect { instance.resolve_toggle(:invalid, nil, default: true, name: "test") }
        .to raise_error(ArgumentError, /Invalid test/)
    end
  end

  describe "#resolve_value_or_toggle" do
    it "returns keyword when provided" do
      expect(instance.resolve_value_or_toggle(:_default_, 10, value_type: Integer, default: 5)).to eq(10)
    end

    it "returns default when UNSET or enabled" do
      expect(instance.resolve_value_or_toggle(:_default_, nil, value_type: Integer, default: 5)).to eq(5)
      expect(instance.resolve_value_or_toggle(true, nil, value_type: Integer, default: 5)).to eq(5)
      expect(instance.resolve_value_or_toggle(:enabled, nil, value_type: Integer, default: 5)).to eq(5)
    end

    it "returns positional when matching value_type" do
      expect(instance.resolve_value_or_toggle(7, nil, value_type: Integer, default: 5)).to eq(7)
    end

    it "returns disabled value when toggled off" do
      expect(instance.resolve_value_or_toggle(false, nil, value_type: Integer, default: 5)).to be_nil
      expect(instance.resolve_value_or_toggle(:disabled, nil, value_type: Integer, default: 5, disabled: 0)).to eq(0)
    end

    it "raises for invalid positional" do
      expect { instance.resolve_value_or_toggle("string", nil, value_type: Integer, default: 5, name: "test") }
        .to raise_error(ArgumentError, /Invalid test/)
    end
  end
end
