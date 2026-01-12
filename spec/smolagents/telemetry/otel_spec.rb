RSpec.describe Smolagents::Telemetry::OTel do
  after do
    described_class.disable
  end

  describe ".enable" do
    context "without OpenTelemetry gems" do
      it "raises LoadError with helpful message" do
        expect { described_class.enable }.to raise_error(LoadError, /OpenTelemetry gems required/)
      end

      it "includes gem installation instructions" do
        expect { described_class.enable }.to raise_error(LoadError, /gem 'opentelemetry-sdk'/)
      end
    end
  end

  describe ".disable" do
    it "clears the subscriber" do
      Smolagents::Instrumentation.subscriber = -> {}
      described_class.disable
      expect(Smolagents::Instrumentation.subscriber).to be_nil
    end

    it "clears the tracer" do
      described_class.instance_variable_set(:@tracer, Object.new)
      described_class.disable
      expect(described_class.tracer).to be_nil
    end
  end

  describe ".enabled?" do
    it "returns false when tracer is nil" do
      expect(described_class.enabled?).to be false
    end

    it "returns true when tracer is set" do
      described_class.instance_variable_set(:@tracer, Object.new)
      expect(described_class.enabled?).to be true
    end
  end

  describe "event handling (integration)" do
    let(:mock_tracer) do
      tracer = instance_double("Tracer")
      allow(tracer).to receive(:in_span).and_yield(mock_span)
      tracer
    end

    let(:mock_span) do
      span = instance_double("Span")
      allow(span).to receive(:set_attribute)
      allow(span).to receive(:status=)
      span
    end

    before do
      described_class.instance_variable_set(:@tracer, mock_tracer)
    end

    it "creates spans for events via handle_event" do
      expect(mock_tracer).to receive(:in_span).with("smolagents/test/event", anything)

      described_class.send(:handle_event, "smolagents.test.event", { duration: 0.5 })
    end

    it "sets ok status for successful events" do
      described_class.send(:handle_event, "test", { duration: 1.234 })

      expect(mock_span).to have_received(:set_attribute).with("smolagents.status", "ok")
    end

    it "records error status for error events" do
      stub_const("OpenTelemetry::Trace::Status", Class.new do
        def self.error(msg)
          "error: #{msg}"
        end
      end)

      described_class.send(:handle_event, "test", { error: "TestError", duration: 0.1 })

      expect(mock_span).to have_received(:set_attribute).with("smolagents.status", "error")
      expect(mock_span).to have_received(:set_attribute).with("smolagents.error_class", "TestError")
    end
  end

  describe "attribute building" do
    it "prefixes attributes with smolagents." do
      attrs = described_class.send(:build_attributes, { model_id: "gpt-4", temperature: 0.7 })

      expect(attrs["smolagents.model_id"]).to eq("gpt-4")
      expect(attrs["smolagents.temperature"]).to eq("0.7")
    end

    it "converts duration to milliseconds" do
      attrs = described_class.send(:build_attributes, { duration: 1.5 })

      expect(attrs["smolagents.duration_ms"]).to eq(1500.0)
    end

    it "excludes non-serializable values" do
      attrs = described_class.send(:build_attributes, {
                                     name: "test",
                                     complex: { nested: "hash" },
                                     array: [1, 2, 3]
                                   })

      expect(attrs.keys).to contain_exactly("smolagents.name")
    end

    it "excludes error and duration from regular attributes" do
      attrs = described_class.send(:build_attributes, {
                                     error: "something",
                                     duration: 1.0,
                                     model: "test"
                                   })

      expect(attrs.keys).to contain_exactly("smolagents.model", "smolagents.duration_ms")
    end

    it "handles boolean values" do
      attrs = described_class.send(:build_attributes, { streaming: true, cache: false })

      expect(attrs["smolagents.streaming"]).to eq("true")
      expect(attrs["smolagents.cache"]).to eq("false")
    end

    it "handles symbol values" do
      attrs = described_class.send(:build_attributes, { status: :success })

      expect(attrs["smolagents.status"]).to eq("success")
    end
  end

  describe "subscriber integration" do
    it "can be set as Instrumentation subscriber" do
      described_class.instance_variable_set(:@tracer, instance_double("Tracer", in_span: nil))

      expect do
        Smolagents::Instrumentation.subscriber = described_class.method(:handle_event)
      end.not_to raise_error
    end
  end
end
