require "spec_helper"

RSpec.describe Smolagents::Builders::PlanningConcern do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::PlanningConcern

      def self.create
        new(configuration: {})
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end

      def check_frozen!
        raise FrozenError if configuration[:__frozen__]
      end

      def freeze!
        with_config(__frozen__: true)
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "#planning" do
    context "with no arguments (default)" do
      it "enables planning with default interval" do
        result = builder.planning

        expect(result.configuration[:planning_interval]).to eq(Smolagents::Config::DEFAULT_PLANNING_INTERVAL)
        expect(result.configuration[:planning_interval]).to eq(3)
      end

      it "returns new builder instance" do
        result = builder.planning

        expect(result).not_to equal(builder)
        expect(result).to be_a(test_builder_class)
      end
    end

    context "with integer argument" do
      it "sets planning interval directly" do
        result = builder.planning(5)

        expect(result.configuration[:planning_interval]).to eq(5)
      end

      it "accepts various interval values" do
        [1, 2, 5, 10, 20, 50].each do |interval|
          result = builder.planning(interval)
          expect(result.configuration[:planning_interval]).to eq(interval)
        end
      end

      it "accepts zero interval" do
        result = builder.planning(0)

        expect(result.configuration[:planning_interval]).to eq(0)
      end
    end

    context "with boolean arguments" do
      it "enables planning with true" do
        result = builder.planning(true)

        expect(result.configuration[:planning_interval]).to eq(3)
      end

      it "disables planning with false" do
        result = builder.planning(false)

        expect(result.configuration[:planning_interval]).to be_nil
      end
    end

    context "with symbol arguments" do
      it "enables planning with :enabled" do
        result = builder.planning(:enabled)

        expect(result.configuration[:planning_interval]).to eq(3)
      end

      it "enables planning with :on" do
        result = builder.planning(:on)

        expect(result.configuration[:planning_interval]).to eq(3)
      end

      it "disables planning with :disabled" do
        result = builder.planning(:disabled)

        expect(result.configuration[:planning_interval]).to be_nil
      end

      it "disables planning with :off" do
        result = builder.planning(:off)

        expect(result.configuration[:planning_interval]).to be_nil
      end

      it "raises error for invalid symbols" do
        expect { builder.planning(:invalid) }
          .to raise_error(ArgumentError, /Invalid planning/)
      end
    end

    context "with named parameter interval:" do
      it "sets planning interval with interval:" do
        result = builder.planning(interval: 7)

        expect(result.configuration[:planning_interval]).to eq(7)
      end

      it "accepts large intervals" do
        result = builder.planning(interval: 100)

        expect(result.configuration[:planning_interval]).to eq(100)
      end

      it "accepts zero interval with keyword" do
        result = builder.planning(interval: 0)

        expect(result.configuration[:planning_interval]).to eq(0)
      end
    end

    context "with templates:" do
      it "sets planning templates" do
        templates = { initial_plan: "Custom template" }
        result = builder.planning(templates:)

        expect(result.configuration[:planning_templates]).to eq(templates)
      end

      it "accepts multiple templates" do
        templates = {
          initial_plan: "Initial",
          replan: "Replan",
          summary: "Summary"
        }
        result = builder.planning(templates:)

        expect(result.configuration[:planning_templates]).to eq(templates)
      end
    end

    context "with both interval and templates" do
      it "sets both interval and templates" do
        templates = { initial_plan: "Custom" }
        result = builder.planning(interval: 5, templates:)

        expect(result.configuration[:planning_interval]).to eq(5)
        expect(result.configuration[:planning_templates]).to eq(templates)
      end

      it "can set templates without interval" do
        templates = { initial_plan: "Custom" }
        result = builder.planning(templates:)

        expect(result.configuration[:planning_templates]).to eq(templates)
        # Interval uses default (3) if not explicitly set to false/nil
        expect(result.configuration[:planning_interval]).to eq(3)
      end
    end

    context "precedence" do
      it "named interval takes precedence over positional" do
        result = builder.planning(10, interval: 7)

        expect(result.configuration[:planning_interval]).to eq(7)
      end

      it "positional boolean with named interval" do
        result = builder.planning(true, interval: 5)

        expect(result.configuration[:planning_interval]).to eq(5)
      end

      it "positional false is overridden by named interval" do
        result = builder.planning(false, interval: 5)

        expect(result.configuration[:planning_interval]).to eq(5)
      end
    end

    context "immutability" do
      it "does not modify original builder" do
        original_config = builder.configuration.dup

        builder.planning(5)

        expect(builder.configuration).to eq(original_config)
      end

      it "returns different instances" do
        result1 = builder.planning(5)
        result2 = builder.planning(10)

        expect(result1).not_to equal(result2)
        expect(result1.configuration[:planning_interval]).to eq(5)
        expect(result2.configuration[:planning_interval]).to eq(10)
      end
    end

    context "chaining" do
      it "can be chained with interval then templates" do
        # When chaining with just templates, must also include interval to preserve it
        result = builder.planning(5).planning(interval: 5, templates: { initial_plan: "Test" })

        expect(result.configuration[:planning_interval]).to eq(5)
        expect(result.configuration[:planning_templates]).to eq(initial_plan: "Test")
      end

      it "can be called multiple times" do
        r1 = builder.planning(5)
        r2 = r1.planning(7)

        expect(r1.configuration[:planning_interval]).to eq(5)
        expect(r2.configuration[:planning_interval]).to eq(7)
      end

      it "can disable then re-enable planning" do
        r1 = builder.planning(false)
        r2 = r1.planning(true)

        expect(r1.configuration[:planning_interval]).to be_nil
        expect(r2.configuration[:planning_interval]).to eq(3)
      end
    end

    context "frozen builder" do
      it "raises FrozenError when frozen" do
        frozen = test_builder_class.create.freeze!

        expect { frozen.planning(5) }.to raise_error(FrozenError)
      end
    end

    context "type validation" do
      it "raises ArgumentError for invalid type string" do
        expect { builder.planning("5") }
          .to raise_error(ArgumentError, /Invalid planning/)
      end

      it "raises ArgumentError for invalid type float" do
        expect { builder.planning(3.14) }
          .to raise_error(ArgumentError, /Invalid planning/)
      end

      it "raises ArgumentError for invalid type hash" do
        expect { builder.planning({}) }
          .to raise_error(ArgumentError, /Invalid planning/)
      end
    end

    context "default constant" do
      it "uses Config::DEFAULT_PLANNING_INTERVAL" do
        result = builder.planning

        expect(result.configuration[:planning_interval])
          .to eq(Smolagents::Config::DEFAULT_PLANNING_INTERVAL)
      end

      it "default interval is stable" do
        r1 = builder.planning
        r2 = builder.planning

        expect(r1.configuration[:planning_interval])
          .to eq(r2.configuration[:planning_interval])
      end
    end

    context "research notes" do
      it "supports planning for improved action recall" do
        # Planning is enabled (70% improvement in Action Recall per documentation)
        result = builder.planning

        expect(result.configuration[:planning_interval]).not_to be_nil
      end

      it "allows disabling planning if not needed" do
        result = builder.planning(false)

        expect(result.configuration[:planning_interval]).to be_nil
      end
    end
  end
end
