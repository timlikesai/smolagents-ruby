RSpec.describe Smolagents::Concerns::BaseConcern do
  describe ".define_composite" do
    let(:sub_module_a) do
      Module.new do
        def method_a = :a
      end
    end

    let(:sub_module_b) do
      Module.new do
        def method_b = :b
      end
    end

    it "creates included hook that includes all sub-modules" do
      composite = Module.new
      described_class.define_composite(composite, sub_module_a, sub_module_b)

      klass = Class.new { include composite }
      instance = klass.new

      expect(instance).to respond_to(:method_a)
      expect(instance).to respond_to(:method_b)
    end

    it "extends class_methods onto including class" do
      class_methods = Module.new do
        def class_dsl_method = :dsl_result
      end

      composite = Module.new
      described_class.define_composite(composite, sub_module_a, class_methods:)

      klass = Class.new { include composite }

      expect(klass).to respond_to(:class_dsl_method)
      expect(klass.class_dsl_method).to eq(:dsl_result)
    end

    context "with conditional modules" do
      let(:events_emitter) do
        Module.new do
          def emit(event) = event
        end
      end

      it "includes conditional modules when not already present" do
        composite = Module.new
        described_class.define_composite(composite, sub_module_a, conditional: [events_emitter])

        klass = Class.new { include composite }

        expect(klass.ancestors).to include(events_emitter)
      end

      it "skips conditional modules when already included" do
        emitter = events_emitter
        a_mod = sub_module_a

        composite = Module.new
        described_class.define_composite(composite, a_mod, conditional: [emitter])

        # Pre-include the conditional module
        base_class = Class.new { include emitter }
        klass = Class.new(base_class) { include composite }

        # Should still work, just not double-include
        expect(klass.new).to respond_to(:emit)
        expect(klass.new).to respond_to(:method_a)
      end
    end

    context "with support_extend: true" do
      it "creates extended hook for instance extension" do
        composite = Module.new
        described_class.define_composite(composite, sub_module_a, sub_module_b, support_extend: true)

        obj = Object.new
        obj.extend(composite)

        expect(obj).to respond_to(:method_a)
        expect(obj).to respond_to(:method_b)
      end

      it "conditionally extends modules" do
        events_emitter = Module.new { def emit(event) = event }

        composite = Module.new
        described_class.define_composite(
          composite, sub_module_a,
          conditional: [events_emitter],
          support_extend: true
        )

        obj = Object.new
        obj.extend(composite)

        expect(obj).to respond_to(:emit)
        expect(obj).to respond_to(:method_a)
      end
    end
  end

  describe ".conditionally_include" do
    let(:module_a) { Module.new { def method_a = :a } }
    let(:module_b) { Module.new { def method_b = :b } }

    it "includes modules not already present" do
      klass = Class.new
      described_class.conditionally_include(klass, module_a, module_b)

      expect(klass.ancestors).to include(module_a, module_b)
    end

    it "skips modules already in ancestry" do
      a_mod = module_a
      b_mod = module_b

      base_class = Class.new { include a_mod }
      klass = Class.new(base_class)

      described_class.conditionally_include(klass, a_mod, b_mod)

      # module_b should be added
      expect(klass.ancestors).to include(b_mod)
      # Ancestry for module_a should be unchanged (still from base_class)
      expect(klass.ancestors.count(a_mod)).to eq(1)
    end
  end

  describe ".conditionally_extend" do
    let(:module_a) { Module.new { def method_a = :a } }
    let(:module_b) { Module.new { def method_b = :b } }

    it "extends modules not already present" do
      obj = Object.new
      described_class.conditionally_extend(obj, module_a, module_b)

      expect(obj).to respond_to(:method_a)
      expect(obj).to respond_to(:method_b)
    end

    it "skips modules already extended" do
      obj = Object.new
      obj.extend(module_a)

      described_class.conditionally_extend(obj, module_a, module_b)

      expect(obj).to respond_to(:method_a)
      expect(obj).to respond_to(:method_b)
    end
  end

  describe "ClassMethodsSupport" do
    it "auto-extends ClassMethods when concern is included" do
      my_config = Module.new do
        include Smolagents::Concerns::BaseConcern::ClassMethodsSupport

        # rubocop:disable RSpec/InstanceVariable
        const_set(:ClassMethods, Module.new do
          def config_setting(value = nil)
            @config_setting = value if value
            @config_setting
          end
        end)
        # rubocop:enable RSpec/InstanceVariable
      end

      config = my_config
      klass = Class.new do
        include config

        config_setting :enabled
      end

      expect(klass.config_setting).to eq(:enabled)
    end

    it "handles concerns without ClassMethods gracefully" do
      my_simple = Module.new do
        include Smolagents::Concerns::BaseConcern::ClassMethodsSupport

        def instance_method = :works
      end

      klass = Class.new { include my_simple }

      expect(klass.new).to respond_to(:instance_method)
    end
  end

  describe "integration with real concern patterns" do
    it "simplifies composite concern definition" do
      # Define sub-concerns
      checks = Module.new { def healthy? = true }
      discovery = Module.new { def available_models = [] }
      class_methods = Module.new { def health_thresholds = { timeout: 10 } }

      # Define composite using BaseConcern
      model_health = Module.new
      described_class.define_composite(
        model_health, checks, discovery,
        class_methods:
      )

      klass = Class.new { include model_health }
      instance = klass.new

      expect(instance).to respond_to(:healthy?)
      expect(instance).to respond_to(:available_models)
      expect(klass).to respond_to(:health_thresholds)
    end

    it "replaces verbose conditional include pattern" do
      events_emitter = Module.new { def emit(event) = event }
      events_consumer = Module.new { def subscribe(event) = event }
      core = Module.new { def run = :running }

      # Old pattern:
      # def self.included(base)
      #   base.include(Events::Emitter) unless base < Events::Emitter
      #   base.include(Events::Consumer) unless base < Events::Consumer
      #   base.include(Core)
      # end

      # New pattern:
      react_loop = Module.new
      described_class.define_composite(
        react_loop, core,
        conditional: [events_emitter, events_consumer]
      )

      klass = Class.new { include react_loop }
      instance = klass.new

      expect(instance).to respond_to(:emit)
      expect(instance).to respond_to(:subscribe)
      expect(instance).to respond_to(:run)
    end
  end
end
