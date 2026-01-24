require "spec_helper"
require_relative "../../../examples/memory/01_memory_basics"

RSpec.describe "Example: Memory Basics", type: :example do
  include Smolagents::Testing::Helpers::ModelHelpers

  describe "create_agent_with_default_memory" do
    it "creates agent with memory configuration" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_default_memory(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "uses full strategy by default" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_default_memory(model)

      # Agent has memory with default config
      expect(agent.memory).to be_a(Smolagents::AgentMemory)
    end
  end

  describe "create_agent_with_budget" do
    it "creates agent with token budget" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_budget(model, budget: 50_000)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it "accepts custom budget values" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_budget(model, budget: 100_000)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_mask_strategy" do
    it "creates agent with mask strategy" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_mask_strategy(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_full_strategy" do
    it "creates agent with full strategy" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_full_strategy(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_agent_with_preserved_steps" do
    it "creates agent with preserve_recent configuration" do
      model = mock_model { |m| m.queue_final_answer("done") }
      agent = create_agent_with_preserved_steps(model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end

  describe "create_memory_config_directly" do
    it "creates a MemoryConfig instance" do
      config = create_memory_config_directly

      expect(config).to be_a(Smolagents::Types::MemoryConfig)
      expect(config.budget).to eq(8000)
      expect(config.mask?).to be true
      expect(config.preserve_recent).to eq(3)
    end
  end

  describe "MemoryConfig" do
    describe "factory methods" do
      it "default creates unlimited full strategy" do
        config = Smolagents::Types::MemoryConfig.default

        expect(config.budget).to be_nil
        expect(config.full?).to be true
      end

      it "masked creates budget-limited mask strategy" do
        config = Smolagents::Types::MemoryConfig.masked(budget: 10_000)

        expect(config.budget).to eq(10_000)
        expect(config.mask?).to be true
      end
    end

    describe "predicates" do
      it "budget? returns true when budget set" do
        config = Smolagents::Types::MemoryConfig.masked(budget: 5000)

        expect(config.budget?).to be true
      end

      it "budget? returns false when no budget" do
        config = Smolagents::Types::MemoryConfig.default

        expect(config.budget?).to be false
      end
    end
  end

  describe "builder DSL" do
    it ".memory with no args enables memory" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .memory
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".memory accepts budget as positional Integer" do
      model = mock_model { |m| m.queue_final_answer("done") }

      builder = Smolagents.agent
                          .model { model }
                          .memory(100_000)

      expect(builder.config[:memory_config].budget).to eq(100_000)
    end

    it ".memory accepts strategy as positional Symbol" do
      model = mock_model { |m| m.queue_final_answer("done") }

      builder = Smolagents.agent
                          .model { model }
                          .memory(:mask)

      expect(builder.config[:memory_config].strategy).to eq(:mask)
    end

    it ".memory accepts budget keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .memory(budget: 25_000)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".memory accepts strategy keyword" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .memory(strategy: :full)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end

    it ".memory accepts all options together" do
      model = mock_model { |m| m.queue_final_answer("done") }

      agent = Smolagents.agent
                        .model { model }
                        .memory(budget: 50_000, strategy: :mask, preserve_recent: 5)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end
end
