require "tempfile"

RSpec.describe Smolagents::TemplateRenderer do
  describe "#initialize" do
    it "loads a YAML template file" do
      yaml_file = Tempfile.new(["test", ".yaml"])
      yaml_file.write("system_prompt: 'Hello <%= name %>'\nplanning: 'Plan for <%= task %>'")
      yaml_file.close

      renderer = described_class.new(yaml_file.path)

      expect(renderer.templates).to be_a(Hash)
      expect(renderer.templates).to have_key("system_prompt")
      expect(renderer.templates).to have_key("planning")

      yaml_file.unlink
    end

    it "raises error for nonexistent file" do
      expect do
        described_class.new("/nonexistent/file.yaml")
      end.to raise_error(ArgumentError, /Template file not found/)
    end

    it "raises error for invalid YAML" do
      invalid_yaml = Tempfile.new(["invalid", ".yaml"])
      invalid_yaml.write("invalid: yaml: content:")
      invalid_yaml.close

      expect do
        described_class.new(invalid_yaml.path)
      end.to raise_error(ArgumentError, /Invalid YAML/)

      invalid_yaml.unlink
    end
  end

  describe ".from_string" do
    it "creates renderer from template string" do
      renderer = described_class.from_string("Hello <%= name %>!")
      result = renderer.render(name: "World")

      expect(result).to eq("Hello World!")
    end
  end

  describe "#render" do
    it "renders template with variables" do
      renderer = described_class.from_string("The answer is <%= number %>.")
      result = renderer.render(number: 42)

      expect(result).to eq("The answer is 42.")
    end

    it "renders template with symbol variables" do
      renderer = described_class.from_string("Hello <%= name %>!")
      result = renderer.render(name: "Alice")

      expect(result).to eq("Hello Alice!")
    end

    it "handles nested objects" do
      renderer = described_class.from_string("User: <%= user[:name] %>, Age: <%= user[:age] %>")
      result = renderer.render(user: { name: "Bob", age: 30 })

      expect(result).to eq("User: Bob, Age: 30")
    end

    it "handles ERB loops" do
      renderer = described_class.from_string("<% items.each do |item| %><%= item %> <% end %>")
      result = renderer.render(items: %w[a b c])

      expect(result).to eq("a b c ")
    end

    it "handles ERB conditionals" do
      renderer = described_class.from_string("<% if show %>visible<% end %>")

      expect(renderer.render(show: true)).to eq("visible")
      expect(renderer.render(show: false)).to eq("")
    end
  end

  describe "#render with YAML template" do
    let(:yaml_content) do
      <<~YAML
        system_prompt: |
          You are a Ruby agent.
          Use <%= code_block_opening_tag %> blocks.
          Close with <%= code_block_closing_tag %>.
        section: "Simple section"
      YAML
    end
    let(:yaml_file) do
      file = Tempfile.new(["test", ".yaml"])
      file.write(yaml_content)
      file.close
      file
    end
    let(:renderer) { described_class.new(yaml_file.path) }

    after { yaml_file.unlink }

    it "renders system_prompt section" do
      result = renderer.render(
        :system_prompt,
        code_block_opening_tag: "```ruby",
        code_block_closing_tag: "```"
      )

      expect(result).to include("Ruby")
      expect(result).to include("```ruby")
      expect(result).to include("```")
    end

    it "renders section with symbol key" do
      result = renderer.render(:section)

      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  describe "#render_nested" do
    let(:yaml_content) do
      <<~YAML
        planning:
          initial_plan: |
            Task: <%= task %>
            Facts survey required.
      YAML
    end
    let(:yaml_file) do
      file = Tempfile.new(["test", ".yaml"])
      file.write(yaml_content)
      file.close
      file
    end
    let(:renderer) { described_class.new(yaml_file.path) }

    after { yaml_file.unlink }

    it "renders nested sections" do
      result = renderer.render_nested("planning.initial_plan", task: "test task")

      expect(result).to include("test task")
      expect(result).to include("Facts survey")
    end
  end

  describe "integration with agents" do
    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test-model")
    end

    let(:mock_tool) do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive(:name).and_return("test_tool")
      allow(tool).to receive(:to_code_prompt).and_return("def test_tool\nend")
      allow(tool).to receive(:to_tool_calling_prompt).and_return("test_tool: test description")
      tool
    end

    it "Agents::Code uses template system" do
      agent = Smolagents::Agents::Code.new(
        tools: [mock_tool],
        model: mock_model
      )

      prompt = agent.system_prompt

      expect(prompt).to be_a(String)
      expect(prompt).to include("Ruby")
      expect(prompt).to include("```ruby")
      # Template successfully loaded and rendered
    end

    it "Agents::ToolCalling uses template system" do
      agent = Smolagents::Agents::ToolCalling.new(
        tools: [mock_tool],
        model: mock_model
      )

      prompt = agent.system_prompt

      expect(prompt).to be_a(String)
      expect(prompt).to include("tool")
      # Template successfully loaded and rendered
    end
  end
end
