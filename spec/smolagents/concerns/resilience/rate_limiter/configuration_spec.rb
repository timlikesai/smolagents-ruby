require "spec_helper"

RSpec.describe Smolagents::Concerns::RateLimiter::Configuration do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::RateLimiter::Configuration
    end
  end

  let(:instance) { test_class.new }

  describe ".rate_limit (class method DSL)" do
    it "configures default rate limit on class" do
      test_class.rate_limit(2.0)
      expect(test_class.default_rate_limit).to eq(2.0)
    end

    it "applies to new instances" do
      test_class.rate_limit(5.0)
      new_instance = test_class.new
      expect(new_instance.limit_interval).to eq(0.2) # 1.0 / 5.0
    end
  end

  describe "#setup_rate_limiter" do
    it "configures rate limiting for instance" do
      instance.setup_rate_limiter(2.0)
      expect(instance.limit_interval).to eq(0.5) # 1.0 / 2.0
    end

    it "sets min_interval based on rate" do
      instance.setup_rate_limiter(10.0)
      expect(instance.limit_interval).to eq(0.1) # 1.0 / 10.0
    end

    it "handles nil rate (disables rate limiting)" do
      instance.setup_rate_limiter(nil)
      expect(instance.limit_interval).to eq(0.0)
    end

    it "initializes request count" do
      instance.setup_rate_limiter(1.0)
      expect(instance.instance_variable_get(:@request_count)).to eq(0)
    end

    it "initializes last request time" do
      instance.setup_rate_limiter(1.0)
      expect(instance.instance_variable_get(:@last_request_time)).to eq(0.0)
    end
  end

  describe "#limit_interval" do
    it "returns min interval between requests" do
      instance.setup_rate_limiter(4.0)
      expect(instance.limit_interval).to eq(0.25)
    end

    it "returns 0 when rate limiting disabled" do
      instance.setup_rate_limiter(nil)
      expect(instance.limit_interval).to eq(0.0)
    end
  end

  describe "parameter validation" do
    it "accepts positive rate" do
      expect { instance.setup_rate_limiter(100.0) }.not_to raise_error
    end

    it "handles large numbers" do
      expect { instance.setup_rate_limiter(1_000_000.0) }.not_to raise_error
    end

    it "handles small rates" do
      instance.setup_rate_limiter(0.1)
      expect(instance.limit_interval).to eq(10.0)
    end
  end

  describe "multiple instances" do
    it "maintains separate configuration per instance" do
      instance1 = test_class.new
      instance2 = test_class.new

      instance1.setup_rate_limiter(2.0)
      instance2.setup_rate_limiter(10.0)

      expect(instance1.limit_interval).to eq(0.5)
      expect(instance2.limit_interval).to eq(0.1)
    end
  end

  describe "class-level configuration inheritance" do
    it "inherits default from class" do
      test_class.rate_limit(5.0)
      new_instance = test_class.new

      expect(new_instance.limit_interval).to eq(0.2)
    end

    it "allows instance override" do
      test_class.rate_limit(5.0)
      new_instance = test_class.new
      new_instance.setup_rate_limiter(10.0)

      expect(new_instance.limit_interval).to eq(0.1)
    end
  end
end
