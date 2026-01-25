require "spec_helper"

RSpec.describe Smolagents::Executors::RactorLazy::FutureIdentity do
  let(:batch) { [] }

  def create_future(name = "test")
    Smolagents::Executors::RactorLazy::ToolFuture.new(name, [], {}, batch)
  end

  describe "#nil?" do
    context "when resolved" do
      it "returns true when resolved to nil" do
        future = create_future
        future._resolve!(nil)

        expect(future.nil?).to be true
      end

      it "returns false when resolved to non-nil value" do
        future = create_future
        future._resolve!("value")

        expect(future.nil?).to be false
      end

      it "returns false when resolved to empty string" do
        future = create_future
        future._resolve!("")

        expect(future.nil?).to be false
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns false as conservative fallback" do
        future = create_future

        expect(future.nil?).to be false
        expect(future._pending?).to be true
      end
    end
  end

  describe "#is_a?" do
    it "returns true for ToolFuture" do
      future = create_future

      expect(future.is_a?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
    end

    it "returns true for BasicObject" do
      future = create_future

      expect(future.is_a?(BasicObject)).to be true
    end

    context "when resolved" do
      it "delegates to resolved value" do
        future = create_future
        future._resolve!("hello")

        expect(future.is_a?(String)).to be true
        expect(future.is_a?(Array)).to be false
      end

      it "works with numeric types" do
        future = create_future
        future._resolve!(42)

        expect(future.is_a?(Integer)).to be true
        expect(future.is_a?(Numeric)).to be true
        expect(future.is_a?(String)).to be false
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns false for other classes" do
        future = create_future

        expect(future.is_a?(String)).to be false
        expect(future.is_a?(Array)).to be false
        expect(future.is_a?(Hash)).to be false
      end
    end
  end

  describe "#kind_of?" do
    it "is aliased to is_a?" do
      future = create_future

      expect(future.is_a?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
      expect(future.is_a?(BasicObject)).to be true
    end

    it "delegates to resolved value" do
      future = create_future
      future._resolve!([1, 2, 3])

      expect(future.is_a?(Array)).to be true
      expect(future.is_a?(Enumerable)).to be true
    end
  end

  describe "#instance_of?" do
    it "returns true for ToolFuture" do
      future = create_future

      expect(future.instance_of?(Smolagents::Executors::RactorLazy::ToolFuture)).to be true
    end

    context "when resolved" do
      it "delegates to resolved value" do
        future = create_future
        future._resolve!("test")

        expect(future.instance_of?(String)).to be true
        expect(future.instance_of?(Object)).to be false
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns false for other classes" do
        future = create_future

        expect(future.instance_of?(BasicObject)).to be false
        expect(future.instance_of?(String)).to be false
      end
    end
  end

  describe "#class" do
    it "always returns ToolFuture" do
      future = create_future

      expect(future.class).to eq(Smolagents::Executors::RactorLazy::ToolFuture)
    end

    it "returns ToolFuture even when resolved" do
      future = create_future
      future._resolve!("string value")

      expect(future.class).to eq(Smolagents::Executors::RactorLazy::ToolFuture)
    end
  end

  describe "#hash" do
    context "when resolved" do
      it "delegates to resolved value" do
        future = create_future
        future._resolve!("hello")

        expect(future.hash).to eq("hello".hash)
      end

      it "produces consistent hash for same value" do
        future1 = create_future("a")
        future2 = create_future("b")
        future1._resolve!("same")
        future2._resolve!("same")

        expect(future1.hash).to eq(future2.hash)
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns object_id based hash" do
        future = create_future

        expect(future.hash).to eq(future.__id__.hash)
      end
    end
  end

  describe "#eql?" do
    context "when resolved" do
      it "returns true for equal values" do
        future = create_future
        future._resolve!("hello")

        expect(future.eql?("hello")).to be true
      end

      it "returns false for non-equal values" do
        future = create_future
        future._resolve!("hello")

        expect(future.eql?("world")).to be false
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns false" do
        future = create_future

        expect(future.eql?("anything")).to be false
      end
    end
  end

  describe "#!" do
    context "when resolved" do
      it "returns false for truthy value" do
        future = create_future
        future._resolve!("truthy")

        expect(!future).to be false
      end

      it "returns true for nil" do
        future = create_future
        future._resolve!(nil)

        expect(!future).to be true
      end

      it "returns true for false" do
        future = create_future
        future._resolve!(false)

        expect(!future).to be true
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns true (unresolved treated as falsy)" do
        future = create_future

        expect(!future).to be true
      end
    end
  end

  describe "#empty?" do
    context "when resolved" do
      it "returns true for empty collection" do
        future = create_future
        future._resolve!([])

        expect(future.empty?).to be true
      end

      it "returns false for non-empty collection" do
        future = create_future
        future._resolve!([1, 2, 3])

        expect(future.empty?).to be false
      end

      it "works with empty string" do
        future = create_future
        future._resolve!("")

        expect(future.empty?).to be true
      end

      it "works with empty hash" do
        future = create_future
        future._resolve!({})

        expect(future.empty?).to be true
      end
    end

    context "when unresolved (FiberError fallback)" do
      it "returns false as conservative fallback" do
        future = create_future

        expect(future.empty?).to be false
      end
    end
  end
end
