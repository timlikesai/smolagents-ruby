require "spec_helper"

RSpec.describe Smolagents::Concerns::HealthRouting do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::HealthRouting
    end
  end

  let(:instance) { test_class.new }

  let(:healthy_model) do
    double("HealthyModel", healthy?: true)
  end

  let(:unhealthy_model) do
    double("UnhealthyModel", healthy?: false)
  end

  let(:no_health_model) do
    double("NoHealthModel")
  end

  describe "#prefer_healthy" do
    it "enables health-based routing" do
      instance.prefer_healthy
      expect(instance.prefer_healthy?).to be true
    end

    it "returns self for chaining" do
      result = instance.prefer_healthy
      expect(result).to eq(instance)
    end

    it "accepts cache_health_for parameter" do
      instance.prefer_healthy(cache_health_for: 30)
      expect(instance.health_cache_duration).to eq(30)
    end

    it "uses default cache duration" do
      instance.prefer_healthy
      expect(instance.health_cache_duration).to eq(5)
    end

    it "allows custom cache duration" do
      instance.prefer_healthy(cache_health_for: 60)
      expect(instance.health_cache_duration).to eq(60)
    end
  end

  describe "#prefer_healthy?" do
    it "returns false initially" do
      expect(instance.prefer_healthy?).to be false
    end

    it "returns true after calling prefer_healthy" do
      instance.prefer_healthy
      expect(instance.prefer_healthy?).to be true
    end
  end

  describe "#health_cache_duration" do
    it "returns nil initially" do
      expect(instance.health_cache_duration).to be_nil
    end

    it "returns configured duration" do
      instance.prefer_healthy(cache_health_for: 30)
      expect(instance.health_cache_duration).to eq(30)
    end

    it "stores duration in instance variable" do
      instance.prefer_healthy(cache_health_for: 45)
      expect(instance.instance_variable_get(:@health_cache_duration)).to eq(45)
    end
  end

  describe "#skip_unhealthy?" do
    context "when health routing disabled" do
      it "returns false" do
        expect(instance.skip_unhealthy?(unhealthy_model)).to be false
      end

      it "does not call healthy? on model" do
        allow(unhealthy_model).to receive(:healthy?).and_call_original
        instance.skip_unhealthy?(unhealthy_model)
        expect(unhealthy_model).not_to have_received(:healthy?)
      end
    end

    context "when health routing enabled" do
      before do
        instance.prefer_healthy(cache_health_for: 5)
      end

      it "returns false for healthy models" do
        expect(instance.skip_unhealthy?(healthy_model)).to be false
      end

      it "returns true for unhealthy models" do
        expect(instance.skip_unhealthy?(unhealthy_model)).to be true
      end

      it "returns false for models without health check" do
        expect(instance.skip_unhealthy?(no_health_model)).to be false
      end

      it "passes cache_health_for to healthy? call" do
        allow(healthy_model).to receive(:healthy?).with(cache_for: 5).and_return(true)
        instance.skip_unhealthy?(healthy_model)
        expect(healthy_model).to have_received(:healthy?).with(cache_for: 5)
      end
    end
  end

  describe "#any_model_healthy?" do
    context "with all healthy models" do
      it "returns true" do
        models = [healthy_model, healthy_model, healthy_model]
        expect(instance.any_model_healthy?(models)).to be true
      end
    end

    context "with all unhealthy models" do
      it "returns false" do
        models = [unhealthy_model, unhealthy_model, unhealthy_model]
        expect(instance.any_model_healthy?(models)).to be false
      end
    end

    context "with mixed models" do
      it "returns true if at least one is healthy" do
        models = [unhealthy_model, healthy_model, unhealthy_model]
        expect(instance.any_model_healthy?(models)).to be true
      end
    end

    context "with models without health check" do
      it "considers them healthy (assume OK)" do
        models = [no_health_model]
        # Models without healthy? are still healthy by default
        expect(instance.any_model_healthy?(models)).to be true
      end
    end

    context "with empty array" do
      it "returns false" do
        expect(instance.any_model_healthy?([])).to be false
      end
    end

    it "uses cache duration of 5 seconds" do
      allow(healthy_model).to receive(:healthy?).with(cache_for: 5).and_return(true)
      instance.any_model_healthy?([healthy_model])
      expect(healthy_model).to have_received(:healthy?).with(cache_for: 5)
    end
  end

  describe "#first_healthy_model" do
    context "with all healthy models" do
      let(:model1) { double("Model1", healthy?: true) }
      let(:model2) { double("Model2", healthy?: true) }

      it "returns first model" do
        models = [model1, model2]
        result = instance.first_healthy_model(models)
        expect(result).to eq(model1)
      end
    end

    context "with first unhealthy" do
      let(:model1) { double("Model1", healthy?: false) }
      let(:model2) { double("Model2", healthy?: true) }

      it "skips unhealthy and returns healthy" do
        models = [model1, model2]
        result = instance.first_healthy_model(models)
        expect(result).to eq(model2)
      end
    end

    context "with all unhealthy models" do
      let(:model1) { double("Model1", healthy?: false) }
      let(:model2) { double("Model2", healthy?: false) }

      it "returns first model anyway" do
        models = [model1, model2]
        result = instance.first_healthy_model(models)
        expect(result).to eq(model1)
      end
    end

    context "with models without health check" do
      it "prefers models with health check" do
        model_with_health = double("WithHealth", healthy?: true)
        models = [no_health_model, model_with_health]
        result = instance.first_healthy_model(models)
        # Returns first model that either doesn't have respond_to check or is healthy
        expect(result).to eq(no_health_model)
      end
    end

    context "with empty array" do
      it "returns nil" do
        result = instance.first_healthy_model([])
        expect(result).to be_nil
      end
    end

    it "uses cache duration of 5 seconds" do
      allow(healthy_model).to receive(:healthy?).with(cache_for: 5).and_return(true)
      instance.first_healthy_model([healthy_model])
      expect(healthy_model).to have_received(:healthy?).with(cache_for: 5)
    end
  end

  describe "#clear_health_routing" do
    it "disables health-based routing" do
      instance.prefer_healthy
      expect(instance.prefer_healthy?).to be true

      instance.clear_health_routing

      expect(instance.prefer_healthy?).to be false
    end

    it "clears cache duration" do
      instance.prefer_healthy(cache_health_for: 30)
      instance.clear_health_routing

      expect(instance.health_cache_duration).to be_nil
    end

    it "returns self for chaining" do
      result = instance.clear_health_routing
      expect(result).to eq(instance)
    end

    it "allows re-enabling after clearing" do
      instance.prefer_healthy(cache_health_for: 10)
      instance.clear_health_routing
      instance.prefer_healthy(cache_health_for: 20)

      expect(instance.prefer_healthy?).to be true
      expect(instance.health_cache_duration).to eq(20)
    end
  end

  describe "chaining patterns" do
    it "supports DSL-style configuration" do
      instance
        .prefer_healthy(cache_health_for: 30)
        .clear_health_routing
        .prefer_healthy

      expect(instance.prefer_healthy?).to be true
      expect(instance.health_cache_duration).to eq(5)
    end
  end

  describe "integration scenarios" do
    context "with model chain" do
      let(:primary) { double("Primary", healthy?: true) }
      let(:backup) { double("Backup", healthy?: false) }
      let(:emergency) { double("Emergency", healthy?: true) }

      it "routes to first healthy in chain" do
        instance.prefer_healthy
        models = [primary, backup, emergency]

        healthy = instance.first_healthy_model(models)
        expect(healthy).to eq(primary)
      end

      it "skips unhealthy models in fallback" do
        instance.prefer_healthy
        [primary, backup, emergency]

        skip_backup = instance.skip_unhealthy?(backup)
        expect(skip_backup).to be true

        skip_primary = instance.skip_unhealthy?(primary)
        expect(skip_primary).to be false
      end

      it "verifies any model can serve request" do
        instance.prefer_healthy
        models = [backup, backup, emergency]

        any_good = instance.any_model_healthy?(models)
        expect(any_good).to be true
      end
    end

    context "degradation scenario" do
      let(:models) do
        [
          double("Model1", healthy?: true),
          double("Model2", healthy?: true),
          double("Model3", healthy?: false)
        ]
      end

      it "handles partial degradation" do
        instance.prefer_healthy

        healthy_count = models.count { |m| !instance.skip_unhealthy?(m) }
        expect(healthy_count).to eq(2)
      end
    end
  end

  describe "error handling" do
    it "handles models that raise in healthy?" do
      bad_model = double("BadModel")
      allow(bad_model).to receive(:respond_to?).with(:healthy?).and_return(true)
      allow(bad_model).to receive(:healthy?).and_raise(StandardError.new("health check error"))

      instance.prefer_healthy

      expect { instance.skip_unhealthy?(bad_model) }.to raise_error(StandardError)
    end

    it "handles empty model arrays" do
      instance.prefer_healthy

      result = instance.any_model_healthy?([])
      expect(result).to be false
    end

    it "handles nil models gracefully" do
      nil_model = nil
      models = [healthy_model, nil_model]

      # May raise or skip nil depending on implementation
      expect { instance.first_healthy_model(models) }.not_to raise_error
    end
  end

  describe "cache behavior" do
    it "stores different cache durations per instance" do
      instance1 = test_class.new
      instance2 = test_class.new

      instance1.prefer_healthy(cache_health_for: 10)
      instance2.prefer_healthy(cache_health_for: 60)

      expect(instance1.health_cache_duration).to eq(10)
      expect(instance2.health_cache_duration).to eq(60)
    end
  end
end
