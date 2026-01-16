RSpec.describe Smolagents::Configuration do
  before do
    Smolagents.reset_configuration!
  end

  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
      expect(config.authorized_imports).to eq(Smolagents::Configuration::DEFAULT_AUTHORIZED_IMPORTS)
      expect(config.audit_logger).to be_nil
      expect(config.log_format).to eq(:text)
      expect(config.log_level).to eq(:info)
      expect(config.search_provider).to eq(:duckduckgo)
    end
  end

  describe "#reset!" do
    it "resets to defaults" do
      config = described_class.new
      config.custom_instructions = "test"
      config.max_steps = 50
      config.audit_logger = Logger.new($stdout)
      config.log_format = :json
      config.log_level = :debug
      config.search_provider = :brave

      config.reset!

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
      expect(config.audit_logger).to be_nil
      expect(config.log_format).to eq(:text)
      expect(config.log_level).to eq(:info)
      expect(config.search_provider).to eq(:duckduckgo)
    end
  end

  describe "validation" do
    it "validates positive max_steps on set" do
      config = described_class.new
      expect { config.max_steps = 0 }.to raise_error(ArgumentError, /max_steps must be positive/)
    end

    it "validates custom_instructions length on set" do
      config = described_class.new
      expect { config.custom_instructions = "a" * 10_001 }.to raise_error(ArgumentError, /custom_instructions too long/)
    end

    it "validate! returns true when valid" do
      config = described_class.new
      expect(config.validate!).to be true
    end
  end

  describe "#log_format=" do
    it "accepts :text" do
      config = described_class.new
      config.log_format = :text
      expect(config.log_format).to eq(:text)
    end

    it "accepts :json" do
      config = described_class.new
      config.log_format = :json
      expect(config.log_format).to eq(:json)
    end

    it "rejects invalid values" do
      config = described_class.new
      expect { config.log_format = :xml }.to raise_error(ArgumentError, /log_format must be :text or :json/)
    end
  end

  describe "#log_level=" do
    it "accepts valid log levels" do
      config = described_class.new

      %i[debug info warn error].each do |level|
        config.log_level = level
        expect(config.log_level).to eq(level)
      end
    end

    it "rejects invalid values" do
      config = described_class.new
      expect { config.log_level = :trace }.to raise_error(ArgumentError, /log_level must be/)
    end
  end

  describe "#search_provider=" do
    it "defaults to :duckduckgo" do
      config = described_class.new
      expect(config.search_provider).to eq(:duckduckgo)
    end

    it "accepts valid providers" do
      config = described_class.new

      %i[duckduckgo bing brave google searxng].each do |provider|
        config.search_provider = provider
        expect(config.search_provider).to eq(provider)
      end
    end

    it "rejects invalid providers" do
      config = described_class.new
      expect { config.search_provider = :invalid }.to raise_error(ArgumentError, /search_provider must be/)
    end
  end
end

RSpec.describe Smolagents, ".configure" do
  before do
    described_class.reset_configuration!
  end

  it "yields configuration object" do
    expect { |b| described_class.configure(&b) }.to yield_with_args(Smolagents::Configuration)
  end

  it "sets configuration values" do
    described_class.configure do |config|
      config.custom_instructions = "Be concise"
      config.max_steps = 15
    end

    expect(described_class.configuration.custom_instructions).to eq("Be concise")
    expect(described_class.configuration.max_steps).to eq(15)
  end

  it "validates configuration after setting" do
    expect do
      described_class.configure do |config|
        config.max_steps = -1
      end
    end.to raise_error(ArgumentError, /max_steps must be positive/)
  end

  it "returns configuration" do
    result = described_class.configure do |config|
      config.max_steps = 10
    end

    expect(result).to be_a(Smolagents::Configuration)
    expect(result.max_steps).to eq(10)
  end
end

RSpec.describe Smolagents, ".configuration" do
  before do
    described_class.reset_configuration!
  end

  it "returns same instance on multiple calls" do
    config1 = described_class.configuration
    config2 = described_class.configuration

    expect(config1).to be(config2)
  end

  it "persists changes" do
    described_class.configuration.custom_instructions = "test"

    expect(described_class.configuration.custom_instructions).to eq("test")
  end
end

RSpec.describe Smolagents, ".reset_configuration!" do
  it "resets to defaults" do
    described_class.configure do |config|
      config.custom_instructions = "test"
      config.max_steps = 50
    end

    described_class.reset_configuration!

    expect(described_class.configuration.custom_instructions).to be_nil
    expect(described_class.configuration.max_steps).to eq(20)
  end
end

RSpec.describe Smolagents, ".audit_logger" do
  before do
    described_class.reset_configuration!
  end

  it "returns nil by default" do
    expect(described_class.audit_logger).to be_nil
  end

  it "returns configured audit_logger" do
    mock_logger = instance_double(Logger)
    described_class.configure do |config|
      config.audit_logger = mock_logger
    end

    expect(described_class.audit_logger).to eq(mock_logger)
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

  it "prevents modification of log_format after freezing" do
    config = described_class.new
    config.log_format = :json
    config.freeze!

    expect { config.log_format = :text }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification of log_level after freezing" do
    config = described_class.new
    config.log_level = :debug
    config.freeze!

    expect { config.log_level = :error }
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
    described_class.reset_configuration!
  end

  it "allows freezing configuration via method chaining" do
    described_class.configure do |config|
      config.custom_instructions = "frozen config"
      config.max_steps = 10
    end.freeze!

    expect(described_class.configuration.frozen?).to be true
    expect(described_class.configuration.custom_instructions).to eq("frozen config")
    expect(described_class.configuration.max_steps).to eq(10)
  end

  it "prevents modification after freezing" do
    described_class.configure do |config|
      config.max_steps = 10
    end.freeze!

    expect { described_class.configuration.max_steps = 20 }
      .to raise_error(FrozenError, "Configuration is frozen")
  end

  it "prevents modification in subsequent configure blocks after freezing" do
    described_class.configure do |config|
      config.max_steps = 10
    end.freeze!

    expect do
      described_class.configure do |config|
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

    threads = Array.new(5) do
      Thread.new do
        expect(Smolagents.configuration.max_steps).to eq(10)
        expect(Smolagents.configuration.custom_instructions).to eq("Thread-safe config")

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
    config.max_steps = 15

    expect(config.max_steps).to eq(15)
  end
end

RSpec.describe Smolagents::Configuration, "#models" do
  before do
    Smolagents.reset_configuration!
  end

  it "allows registering model factories" do
    config = described_class.new
    config.models do |m|
      m = m.register(:test, -> { "test_model" })
      m
    end
    expect(config.model_palette.get(:test)).to eq("test_model")
  end

  it "supports chaining multiple registrations" do
    config = described_class.new
    config.models do |m|
      m = m.register(:fast, -> { "fast_model" })
      m = m.register(:smart, -> { "smart_model" })
      m
    end
    expect(config.model_palette.get(:fast)).to eq("fast_model")
    expect(config.model_palette.get(:smart)).to eq("smart_model")
  end

  it "raises when configuration is frozen" do
    config = described_class.new
    config.freeze!

    expect { config.models { |m| m } }.to raise_error(FrozenError)
  end
end

RSpec.describe Smolagents, ".get_model" do
  before do
    described_class.reset_configuration!
  end

  it "retrieves a registered model" do
    described_class.configure do |c|
      c.models do |m|
        m = m.register(:test_model, -> { "the_model_instance" })
        m
      end
    end

    expect(described_class.get_model(:test_model)).to eq("the_model_instance")
  end

  it "raises for unregistered model" do
    expect { described_class.get_model(:nonexistent) }.to raise_error(ArgumentError, /Model not registered/)
  end
end
