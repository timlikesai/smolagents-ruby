require "spec_helper"

RSpec.describe Smolagents::Types::ControlRequests::DSL do
  describe Smolagents::Types::ControlRequests::RequestConfig do
    subject(:config) do
      described_class.new(
        fields: %i[prompt options],
        defaults: { options: nil },
        freeze: [:options],
        predicates: { has_options: ->(r) { r.options&.any? || false } }
      )
    end

    it "is a Data.define type" do
      expect(described_class.ancestors).to include(Data)
    end

    describe "#all_fields" do
      it "prepends :id and appends :created_at to fields" do
        expect(config.all_fields).to eq(%i[id prompt options created_at])
      end
    end
  end

  describe Smolagents::Types::ControlRequests::RequestBuilder do
    describe ".build" do
      subject(:klass) { described_class.build(config) }

      let(:config) do
        Smolagents::Types::ControlRequests::RequestConfig.new(
          fields: %i[name value],
          defaults: { value: "default" },
          freeze: [:name],
          predicates: { has_value: ->(r) { !r.value.nil? } }
        )
      end

      it "creates a Data.define class" do
        expect(klass.ancestors).to include(Data)
      end

      it "includes id and created_at fields" do
        expect(klass.members).to include(:id, :created_at)
      end

      it "includes specified fields" do
        expect(klass.members).to include(:name, :value)
      end

      it "includes Request module" do
        instance = klass.create(name: "test")
        expect(instance.request?).to be true
      end

      it "provides request_config class method" do
        expect(klass.request_config).to eq(config)
      end

      it "provides create class method" do
        expect(klass).to respond_to(:create)
      end

      it "generates predicate methods" do
        instance = klass.create(name: "test", value: "present")
        expect(instance).to respond_to(:has_value?)
        expect(instance.has_value?).to be true
      end
    end
  end

  describe Smolagents::Types::ControlRequests::CreateFactory do
    describe ".call" do
      let(:config) do
        Smolagents::Types::ControlRequests::RequestConfig.new(
          fields: %i[prompt context],
          defaults: { context: {} },
          freeze: [:context],
          predicates: {}
        )
      end
      let(:klass) { Smolagents::Types::ControlRequests::RequestBuilder.build(config) }

      it "generates unique UUID for id" do
        r1 = described_class.call(klass, { prompt: "a" })
        r2 = described_class.call(klass, { prompt: "b" })
        expect(r1.id).to match(/\A[0-9a-f-]{36}\z/)
        expect(r1.id).not_to eq(r2.id)
      end

      it "sets created_at timestamp" do
        result = described_class.call(klass, { prompt: "test" })
        expect(result.created_at).to be_within(1).of(Time.now)
      end

      it "applies defaults for missing keys" do
        result = described_class.call(klass, { prompt: "test" })
        expect(result.context).to eq({})
      end

      it "preserves explicitly provided values" do
        result = described_class.call(klass, { prompt: "test", context: { key: "val" } })
        expect(result.context).to eq({ key: "val" })
      end

      it "freezes specified fields" do
        result = described_class.call(klass, { prompt: "test", context: { mutable: true } })
        expect(result.context).to be_frozen
      end

      it "handles nil values in freeze list gracefully" do
        result = described_class.call(klass, { prompt: "test", context: nil })
        expect(result.context).to be_nil
      end
    end
  end

  describe "DSL module integration" do
    let(:test_module) do
      Module.new do
        extend Smolagents::Types::ControlRequests::DSL
      end
    end

    describe "#define_request" do
      before do
        test_module.define_request(
          :TestRequest,
          fields: %i[message level],
          defaults: { level: :info },
          freeze: [],
          predicates: { error?: ->(r) { r.level == :error } }
        )
      end

      it "defines a constant for the request type" do
        expect(test_module.const_defined?(:TestRequest)).to be true
      end

      it "defines a factory method with snake_case name" do
        expect(test_module).to respond_to(:test_request)
      end

      it "factory method creates instances" do
        request = test_module.test_request(message: "Hello")
        expect(request).to be_a(test_module::TestRequest)
        expect(request.message).to eq("Hello")
        expect(request.level).to eq(:info)
      end

      it "includes Request module in generated class" do
        request = test_module.test_request(message: "Hello")
        expect(request.request?).to be true
        expect(request.request_type).to eq(:test_request)
      end
    end

    describe "factory method name conversion" do
      before do
        test_module.define_request(
          :MultiWordTypeName,
          fields: [:data],
          defaults: {},
          freeze: [],
          predicates: {}
        )
      end

      it "converts CamelCase to snake_case" do
        expect(test_module).to respond_to(:multi_word_type_name)
      end
    end
  end
end
