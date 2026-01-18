require "spec_helper"

RSpec.describe Smolagents::Builders::Support::Introspection do
  describe "AgentBuilder introspection" do
    let(:builder) { Smolagents.agent }

    describe ".available_methods" do
      subject(:methods) { Smolagents::Builders::AgentBuilder.available_methods }

      it "returns methods grouped by category" do
        expect(methods).to have_key(:required)
        expect(methods).to have_key(:optional)
      end

      it "includes required methods" do
        required_names = methods[:required].map { it[:name] }
        expect(required_names).to include(:model)
      end

      it "includes optional methods" do
        optional_names = methods[:optional].map { it[:name] }
        expect(optional_names).to include(:max_steps)
        expect(optional_names).to include(:planning)
        expect(optional_names).to include(:instructions)
      end

      it "includes method descriptions" do
        model_method = methods[:required].find { it[:name] == :model }
        expect(model_method[:description]).to include("model")
      end

      it "includes required flag" do
        model_method = methods[:required].find { it[:name] == :model }
        expect(model_method[:required]).to be true

        max_steps_method = methods[:optional].find { it[:name] == :max_steps }
        expect(max_steps_method[:required]).to be false
      end

      it "excludes aliases from listing" do
        all_names = methods.values.flatten.map { it[:name] }
        # Aliases have alias_of metadata set; verify none are included
        aliases = methods.values.flatten.select { it[:aliases]&.any? }.flat_map { it[:aliases] }
        aliases.each { |a| expect(all_names).not_to include(a) }
      end
    end

    describe ".method_documentation" do
      subject(:docs) { Smolagents::Builders::AgentBuilder.method_documentation }

      it "returns formatted string" do
        expect(docs).to be_a(String)
      end

      it "includes category headers" do
        expect(docs).to include("## Required")
        expect(docs).to include("## Optional")
      end

      it "includes method entries" do
        expect(docs).to include(".model")
        expect(docs).to include(".max_steps")
      end

      it "includes descriptions" do
        expect(docs).to match(/\.model.*-.*/)
      end
    end

    describe "#summary" do
      it "returns builder state hash" do
        summary = builder.summary

        expect(summary).to have_key(:builder_type)
        expect(summary).to have_key(:configured)
        expect(summary).to have_key(:missing_required)
        expect(summary).to have_key(:ready_to_build)
      end

      it "identifies builder type" do
        expect(builder.summary[:builder_type]).to eq("AgentBuilder")
      end

      it "shows unconfigured builder as not ready" do
        expect(builder.summary[:ready_to_build]).to be false
        expect(builder.summary[:missing_required]).to include(:model)
      end

      it "shows configured builder as ready" do
        configured = builder.model { Smolagents::Testing::MockModel.new }
        summary = configured.summary

        expect(summary[:ready_to_build]).to be true
        expect(summary[:missing_required]).to be_empty
      end

      it "summarizes configuration values" do
        configured = builder
                     .model { Smolagents::Testing::MockModel.new }
                     .tools(:search, :web)
                     .max_steps(10)

        summary = configured.summary[:configured]

        expect(summary[:model_block]).to eq("<block>")
        # :search and :web categories expand to 4 tool names
        expect(summary[:tool_names]).to match(/\[\d+ items\]/)
        expect(summary[:max_steps]).to eq("10")
      end
    end

    describe "#ready_to_build?" do
      it "returns false when model not set" do
        expect(builder.ready_to_build?).to be false
      end

      it "returns true when model set" do
        configured = builder.model { Smolagents::Testing::MockModel.new }
        expect(configured.ready_to_build?).to be true
      end
    end

    describe "#missing_required_fields" do
      it "lists missing required methods" do
        expect(builder.missing_required_fields).to include(:model)
      end

      it "returns empty when all required set" do
        configured = builder.model { Smolagents::Testing::MockModel.new }
        expect(configured.missing_required_fields).to be_empty
      end
    end
  end

  describe "ModelBuilder introspection" do
    let(:builder) { Smolagents.model(:openai) }

    describe ".available_methods" do
      subject(:methods) { Smolagents::Builders::ModelBuilder.available_methods }

      it "includes required id method" do
        required_names = methods[:required].map { it[:name] }
        expect(required_names).to include(:id)
      end

      it "includes optional methods" do
        optional_names = methods[:optional].map { it[:name] }
        expect(optional_names).to include(:temperature)
        expect(optional_names).to include(:max_tokens)
        expect(optional_names).to include(:api_key)
      end

      it "includes aliases" do
        temp_method = methods[:optional].find { it[:name] == :temperature }
        expect(temp_method[:aliases]).to include(:temp)
      end
    end

    describe "#summary" do
      it "identifies missing id" do
        summary = builder.summary

        expect(summary[:missing_required]).to include(:id)
        expect(summary[:ready_to_build]).to be false
      end

      it "shows ready when id set" do
        configured = builder.id("gpt-4").api_key("test")
        summary = configured.summary

        expect(summary[:missing_required]).to be_empty
        expect(summary[:ready_to_build]).to be true
      end

      it "summarizes configuration" do
        configured = builder.id("gpt-4").temperature(0.7)
        summary = configured.summary[:configured]

        expect(summary[:model_id]).to eq("gpt-4")
        expect(summary[:temperature]).to eq("0.7")
      end
    end
  end

  describe "TeamBuilder introspection" do
    let(:builder) { Smolagents.team }

    describe ".available_methods" do
      subject(:methods) { Smolagents::Builders::TeamBuilder.available_methods }

      it "includes required agent method" do
        required_names = methods[:required].map { it[:name] }
        expect(required_names).to include(:agent)
      end

      it "includes optional methods" do
        optional_names = methods[:optional].map { it[:name] }
        expect(optional_names).to include(:coordinate)
        expect(optional_names).to include(:max_steps)
      end
    end

    describe "#summary" do
      it "identifies missing agent" do
        summary = builder.summary

        expect(summary[:missing_required]).to include(:agent)
        expect(summary[:ready_to_build]).to be false
      end
    end
  end

  describe "TestBuilder introspection" do
    let(:builder) { Smolagents::Builders::TestBuilder.new }

    describe ".available_methods" do
      subject(:methods) { Smolagents::Builders::TestBuilder.available_methods }

      it "includes required methods" do
        required_names = methods[:required].map { it[:name] }
        expect(required_names).to include(:task)
        expect(required_names).to include(:expects)
      end

      it "includes optional methods" do
        optional_names = methods[:optional].map { it[:name] }
        expect(optional_names).to include(:max_steps)
        expect(optional_names).to include(:timeout)
        expect(optional_names).to include(:run_n_times)
        expect(optional_names).to include(:tools)
      end
    end

    describe ".method_documentation" do
      subject(:docs) { Smolagents::Builders::TestBuilder.method_documentation }

      it "returns formatted documentation" do
        expect(docs).to include("## Required")
        expect(docs).to include(".task")
        expect(docs).to include(".expects")
        expect(docs).to include("## Optional")
        expect(docs).to include(".max_steps")
      end
    end

    describe "#summary" do
      it "identifies missing required fields" do
        summary = builder.summary

        expect(summary[:builder_type]).to eq("TestBuilder")
        expect(summary[:missing_required]).to include(:task)
        expect(summary[:missing_required]).to include(:expects)
        expect(summary[:ready_to_build]).to be false
      end

      it "shows ready when required fields set" do
        configured = builder.task("What is 2+2?").expects { |r| r.include?("4") }
        summary = configured.summary

        expect(summary[:missing_required]).to be_empty
        expect(summary[:ready_to_build]).to be true
      end

      it "summarizes mutable configuration" do
        builder.task("test task")
        builder.max_steps(10)
        builder.tools(:search, :web)

        summary = builder.summary[:configured]

        expect(summary[:task]).to eq("test task")
        expect(summary[:max_steps]).to eq("10")
        expect(summary[:tools]).to eq("[2 items]")
      end

      it "shows validator as block" do
        builder.task("test").expects { |r| r == "expected" }

        summary = builder.summary[:configured]
        expect(summary[:validator]).to eq("<block>")
      end
    end

    describe "#ready_to_build?" do
      it "returns false when task and expects not set" do
        expect(builder.ready_to_build?).to be false
      end

      it "returns false when only task set" do
        builder.task("test")
        expect(builder.ready_to_build?).to be false
      end

      it "returns true when task and expects set" do
        builder.task("test").expects { true }
        expect(builder.ready_to_build?).to be true
      end
    end
  end
end
