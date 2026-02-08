RSpec.describe "Smolagents.configure with profile", type: :integration do
  after { Smolagents.reset_configuration! }

  it "applies profile before yielding" do
    Smolagents.configure(:local_gpu) do |config|
      expect(config.max_steps).to eq(Smolagents::Types::ConfigProfile.local_gpu.overrides[:max_steps])
    end
  end

  it "allows block overrides after profile" do
    Smolagents.configure(:local_gpu) do |config|
      config.max_steps = 99
    end
    expect(Smolagents.configuration.max_steps).to eq(99)
  end

  it "works without a block" do
    Smolagents.configure(:development)
    expect(Smolagents.configuration.log_level).to eq(:debug)
  end

  it "works without a profile (backward compatible)" do
    Smolagents.configure do |config|
      config.max_steps = 42
    end
    expect(Smolagents.configuration.max_steps).to eq(42)
  end
end
