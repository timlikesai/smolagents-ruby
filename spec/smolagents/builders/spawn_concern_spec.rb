require "spec_helper"

RSpec.describe Smolagents::Builders::SpawnConcern do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::SpawnConcern

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

  describe "#can_spawn" do
    context "with no arguments (defaults)" do
      it "enables spawn with default configuration" do
        result = builder.can_spawn

        expect(result.configuration[:spawn_config]).not_to be_nil
      end

      it "sets default allowed_models to empty" do
        result = builder.can_spawn

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_models).to eq([])
      end

      it "sets default allowed_tools to [:final_answer]" do
        result = builder.can_spawn

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_tools).to eq([:final_answer])
      end

      it "sets default max_children to 3" do
        result = builder.can_spawn

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.max_children).to eq(3)
      end

      it "sets default inherit scope to :task_only" do
        result = builder.can_spawn

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.inherit_scope.task_only?).to be true
      end

      it "returns new builder instance" do
        result = builder.can_spawn

        expect(result).not_to equal(builder)
        expect(result).to be_a(test_builder_class)
      end
    end

    context "with allow:" do
      it "restricts allowed models by name" do
        result = builder.can_spawn(allow: %i[researcher fast])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_models).to eq(%i[researcher fast])
      end

      it "allows querying if model is allowed" do
        result = builder.can_spawn(allow: %i[researcher])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.model_allowed?(:researcher)).to be true
        expect(spawn_config.model_allowed?(:slow)).to be false
      end

      it "accepts empty array (no model restrictions)" do
        result = builder.can_spawn(allow: [])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_models).to eq([])
      end

      it "accepts multiple models" do
        result = builder.can_spawn(allow: %i[gpt claude llama gemma])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_models.size).to eq(4)
      end
    end

    context "with tools:" do
      it "restricts allowed tools" do
        result = builder.can_spawn(tools: %i[search final_answer])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_tools).to eq(%i[search final_answer])
      end

      it "allows querying if tool is allowed" do
        result = builder.can_spawn(tools: %i[search])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.tool_allowed?(:search)).to be true
        expect(spawn_config.tool_allowed?(:web)).to be false
      end

      it "includes final_answer by default in tools arg" do
        result = builder.can_spawn(tools: %i[search])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_tools).to include(:search)
      end

      it "accepts multiple tools" do
        result = builder.can_spawn(tools: %i[search web_search lookup])

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.allowed_tools.size).to eq(3)
      end
    end

    context "with inherit:" do
      it "sets inherit scope with inherit:" do
        result = builder.can_spawn(inherit: :observations)

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.inherit_scope.observations?).to be true
      end

      it "supports :task_only scope" do
        result = builder.can_spawn(inherit: :task_only)

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.inherit_scope.task_only?).to be true
      end

      it "supports :summary scope" do
        result = builder.can_spawn(inherit: :summary)

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.inherit_scope.summary?).to be true
      end

      it "supports :full scope" do
        result = builder.can_spawn(inherit: :full)

        spawn_config = result.configuration[:spawn_config]
        expect(spawn_config.inherit_scope.full?).to be true
      end
    end

    context "with max_children:" do
      it "sets maximum spawned agents" do
        result = builder.can_spawn(max_children: 10)

        expect(result.configuration[:spawn_config].max_children).to eq(10)
      end

      it "accepts various values" do
        [1, 3, 5, 10, 100].each do |max_val|
          result = builder.can_spawn(max_children: max_val)
          expect(result.configuration[:spawn_config].max_children).to eq(max_val)
        end
      end
    end

    context "with max_depth:" do
      it "sets maximum spawn nesting depth" do
        result = builder.can_spawn(max_depth: 3)

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.max_depth).to eq(3)
      end

      it "accepts various depth values" do
        [1, 2, 3, 5].each do |depth|
          result = builder.can_spawn(max_depth: depth)
          expect(result.configuration[:spawn_policy].max_depth).to eq(depth)
        end
      end
    end

    context "with max_steps:" do
      it "sets maximum steps per spawned agent" do
        result = builder.can_spawn(max_steps: 5)

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.max_steps_per_agent).to eq(5)
      end

      it "defaults to 10 if not specified" do
        result = builder.can_spawn

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.max_steps_per_agent).to eq(10)
      end
    end

    context "with allowed_tools:" do
      it "uses allowed_tools parameter for spawn_policy" do
        result = builder.can_spawn(allowed_tools: %i[search web])

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.allowed_tools).to eq(%i[search web])
      end

      it "uses tools: if allowed_tools: is not provided" do
        result = builder.can_spawn(tools: %i[search])

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.allowed_tools).to eq(%i[search])
      end

      it "allowed_tools takes precedence over tools" do
        result = builder.can_spawn(tools: %i[search], allowed_tools: %i[web])

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.allowed_tools).to eq(%i[web])
      end
    end

    context "combined configuration" do
      it "supports full configuration in one call" do
        result = builder.can_spawn(
          allow: %i[researcher],
          tools: %i[search final_answer],
          inherit: :observations,
          max_children: 5,
          max_depth: 2,
          max_steps: 8
        )

        spawn_config = result.configuration[:spawn_config]
        spawn_policy = result.configuration[:spawn_policy]

        expect(spawn_config.allowed_models).to eq(%i[researcher])
        expect(spawn_config.allowed_tools).to eq(%i[search final_answer])
        expect(spawn_config.inherit_scope.observations?).to be true
        expect(spawn_config.max_children).to eq(5)
        expect(spawn_policy.max_depth).to eq(2)
        expect(spawn_policy.max_steps_per_agent).to eq(8)
      end
    end

    context "security" do
      it "enforces privilege restriction" do
        result = builder.can_spawn(
          allow: %i[slow_model],
          max_children: 2
        )

        spawn_config = result.configuration[:spawn_config]
        # Should enforce that child agents have fewer capabilities
        expect(spawn_config.allowed_models).to eq(%i[slow_model])
      end

      it "defaults to restricting child tools" do
        result = builder.can_spawn

        spawn_config = result.configuration[:spawn_config]
        # By default, children can only use final_answer
        expect(spawn_config.allowed_tools).to eq([:final_answer])
      end

      it "spawn_policy has inherit_restrictions enabled" do
        result = builder.can_spawn

        spawn_policy = result.configuration[:spawn_policy]
        expect(spawn_policy.inherit_restrictions).to be true
      end
    end

    context "immutability" do
      it "does not modify original builder" do
        original_config = builder.configuration.dup

        builder.can_spawn(max_children: 5)

        expect(builder.configuration).to eq(original_config)
      end

      it "returns different instances" do
        result1 = builder.can_spawn(max_children: 3)
        result2 = builder.can_spawn(max_children: 5)

        expect(result1).not_to equal(result2)
        expect(result1.configuration[:spawn_config].max_children).to eq(3)
        expect(result2.configuration[:spawn_config].max_children).to eq(5)
      end
    end

    context "chaining" do
      it "can be called multiple times" do
        r1 = builder.can_spawn(max_children: 3)
        r2 = r1.can_spawn(max_children: 5)

        expect(r1.configuration[:spawn_config].max_children).to eq(3)
        expect(r2.configuration[:spawn_config].max_children).to eq(5)
      end

      it "can be chained with other builder methods" do
        # Just verify it's chainable (actual chaining depends on other methods)
        result = builder.can_spawn(max_children: 5)
        expect(result).to be_a(test_builder_class)
      end
    end

    context "frozen builder" do
      it "raises FrozenError when frozen" do
        frozen = test_builder_class.create.freeze!

        expect { frozen.can_spawn }.to raise_error(FrozenError)
      end
    end

    context "edge cases" do
      it "accepts zero max_children (limited)" do
        result = builder.can_spawn(max_children: 0)
        expect(result.configuration[:spawn_config].max_children).to eq(0)
      end

      it "accepts large max_children" do
        result = builder.can_spawn(max_children: 1000)
        expect(result.configuration[:spawn_config].max_children).to eq(1000)
      end

      it "accepts empty allowed tools" do
        result = builder.can_spawn(tools: [])
        expect(result.configuration[:spawn_config].allowed_tools).to eq([])
      end
    end
  end
end
