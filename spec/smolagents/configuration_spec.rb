# frozen_string_literal: true

RSpec.describe Smolagents::Configuration do
  # Reset configuration before each test
  before do
    Smolagents.reset_configuration!
  end

  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
      expect(config.authorized_imports).to eq(Smolagents::CodeAgent::DEFAULT_AUTHORIZED_IMPORTS)
      expect(config.audit_logger).to be_nil
    end
  end

  describe "#reset!" do
    it "resets to defaults" do
      config = described_class.new
      config.custom_instructions = "test"
      config.max_steps = 50
      config.audit_logger = Logger.new($stdout)

      config.reset!

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
      expect(config.audit_logger).to be_nil
    end
  end

  describe "#validate!" do
    it "validates positive max_steps" do
      config = described_class.new
      config.max_steps = 0

      expect { config.validate! }.to raise_error(ArgumentError, /max_steps must be positive/)
    end

    it "validates authorized_imports is array" do
      config = described_class.new
      config.authorized_imports = "not an array"

      expect { config.validate! }.to raise_error(ArgumentError, /authorized_imports must be an array/)
    end

    it "validates custom_instructions length" do
      config = described_class.new
      config.custom_instructions = "a" * 10_001

      expect { config.validate! }.to raise_error(ArgumentError, /custom_instructions too long/)
    end

    it "returns true when valid" do
      config = described_class.new

      expect(config.validate!).to be true
    end
  end
end

RSpec.describe Smolagents, ".configure" do
  before do
    Smolagents.reset_configuration!
  end

  it "yields configuration object" do
    expect { |b| Smolagents.configure(&b) }.to yield_with_args(Smolagents::Configuration)
  end

  it "sets configuration values" do
    Smolagents.configure do |config|
      config.custom_instructions = "Be concise"
      config.max_steps = 15
    end

    expect(Smolagents.configuration.custom_instructions).to eq("Be concise")
    expect(Smolagents.configuration.max_steps).to eq(15)
  end

  it "validates configuration after setting" do
    expect do
      Smolagents.configure do |config|
        config.max_steps = -1
      end
    end.to raise_error(ArgumentError, /max_steps must be positive/)
  end

  it "returns configuration" do
    result = Smolagents.configure do |config|
      config.max_steps = 10
    end

    expect(result).to be_a(Smolagents::Configuration)
    expect(result.max_steps).to eq(10)
  end
end

RSpec.describe Smolagents, ".configuration" do
  before do
    Smolagents.reset_configuration!
  end

  it "returns same instance on multiple calls" do
    config1 = Smolagents.configuration
    config2 = Smolagents.configuration

    expect(config1).to be(config2)
  end

  it "persists changes" do
    Smolagents.configuration.custom_instructions = "test"

    expect(Smolagents.configuration.custom_instructions).to eq("test")
  end
end

RSpec.describe Smolagents, ".reset_configuration!" do
  it "resets to defaults" do
    Smolagents.configure do |config|
      config.custom_instructions = "test"
      config.max_steps = 50
    end

    Smolagents.reset_configuration!

    expect(Smolagents.configuration.custom_instructions).to be_nil
    expect(Smolagents.configuration.max_steps).to eq(20)
  end
end

RSpec.describe Smolagents, ".audit_logger" do
  before do
    Smolagents.reset_configuration!
  end

  it "returns nil by default" do
    expect(Smolagents.audit_logger).to be_nil
  end

  it "returns configured audit_logger" do
    mock_logger = instance_double(Logger)
    Smolagents.configure do |config|
      config.audit_logger = mock_logger
    end

    expect(Smolagents.audit_logger).to eq(mock_logger)
  end
end

RSpec.describe Smolagents::Configuration, "#freeze!" do
  it "freezes the configuration" do
    config = described_class.new
    expect(config.frozen?).to be false

    config.freeze!

    expect(config.frozen?).to be true
  end

  it "returns self for method chaining" do
    config = described_class.new
    result = config.freeze!

    expect(result).to be(config)
  end

  it "prevents modification of custom_instructions after freezing" do
    config = described_class.new
    config.custom_instructions = "initial"
    config.freeze!

    expect { config.custom_instructions = "modified" }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification of max_steps after freezing" do
    config = described_class.new
    config.max_steps = 10
    config.freeze!

    expect { config.max_steps = 20 }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification of authorized_imports after freezing" do
    config = described_class.new
    config.authorized_imports = %w[json csv]
    config.freeze!

    expect { config.authorized_imports = %w[yaml] }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification of audit_logger after freezing" do
    config = described_class.new
    mock_logger = instance_double(Logger)
    config.audit_logger = mock_logger
    config.freeze!

    expect { config.audit_logger = Logger.new($stdout) }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "allows reading values after freezing" do
    config = described_class.new
    config.custom_instructions = "test"
    config.max_steps = 15
    config.freeze!

    expect(config.custom_instructions).to eq("test")
    expect(config.max_steps).to eq(15)
  end
end

RSpec.describe Smolagents, ".configure with freeze!" do
  before do
    Smolagents.reset_configuration!
  end

  it "allows freezing configuration via method chaining" do
    Smolagents.configure do |config|
      config.custom_instructions = "frozen config"
      config.max_steps = 10
    end.freeze!

    expect(Smolagents.configuration.frozen?).to be true
    expect(Smolagents.configuration.custom_instructions).to eq("frozen config")
    expect(Smolagents.configuration.max_steps).to eq(10)
  end

  it "prevents modification after freezing" do
    Smolagents.configure do |config|
      config.max_steps = 10
    end.freeze!

    expect { Smolagents.configuration.max_steps = 20 }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification in subsequent configure blocks after freezing" do
    Smolagents.configure do |config|
      config.max_steps = 10
    end.freeze!

    expect do
      Smolagents.configure do |config|
        config.max_steps = 20
      end
    end.to raise_error(FrozenError, "Configuration is frozen")
  end
end

RSpec.describe "Thread-safety with frozen configuration" do
  before do
    Smolagents.reset_configuration!
  end

  it "prevents race conditions by freezing configuration" do
    Smolagents.configure do |config|
      config.max_steps = 10
      config.custom_instructions = "Thread-safe config"
    end.freeze!

    threads = 5.times.map do
      Thread.new do
        # Reading should work in all threads
        expect(Smolagents.configuration.max_steps).to eq(10)
        expect(Smolagents.configuration.custom_instructions).to eq("Thread-safe config")

        # Writing should fail in all threads
        expect { Smolagents.configuration.max_steps = 20 }
          .to raise_error(FrozenError, "Configuration is frozen")
      end
    end

    threads.each(&:join)
  end
end

RSpec.describe Smolagents::Configuration, "#reset!" do
  it "unfreezes configuration when reset" do
    config = described_class.new
    config.max_steps = 10
    config.freeze!

    expect(config.frozen?).to be true

    config.reset!

    expect(config.frozen?).to be false
    config.max_steps = 15 # Should not raise

    expect(config.max_steps).to eq(15)
  end
end
