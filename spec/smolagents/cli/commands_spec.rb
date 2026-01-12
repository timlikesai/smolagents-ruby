# frozen_string_literal: true

require "thor"
require "smolagents/cli/commands"
require "smolagents/cli/model_builder"

RSpec.describe Smolagents::CLI::Commands do
  let(:test_class) do
    Class.new do
      include Thor::Shell
      include Smolagents::CLI::ModelBuilder
      include Smolagents::CLI::Commands

      attr_accessor :options

      def initialize
        @options = {}
      end
    end
  end

  let(:command) { test_class.new }

  describe "#tools" do
    before do
      # Stub registry with only tools that don't require API keys
      stub_const("Smolagents::Tools::REGISTRY", { "final_answer" => Smolagents::FinalAnswerTool })
    end

    it "lists available tools" do
      expect { command.tools }.to output(/Available tools/).to_stdout
    end

    it "shows tool descriptions" do
      expect { command.tools }.to output(/final_answer/).to_stdout
    end
  end

  describe "#models" do
    it "lists model providers" do
      expect { command.models }.to output(/Model providers/).to_stdout
    end

    it "shows OpenAI examples" do
      expect { command.models }.to output(/OpenAI/).to_stdout
    end

    it "shows Anthropic examples" do
      expect { command.models }.to output(/Anthropic/).to_stdout
    end

    it "shows local provider examples" do
      expect { command.models }.to output(/Local/).to_stdout
    end
  end
end
