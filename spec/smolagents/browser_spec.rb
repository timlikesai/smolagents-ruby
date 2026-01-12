require "smolagents"

RSpec.describe Smolagents::Concerns::Browser do
  describe "INSTRUCTIONS" do
    it "provides browser usage instructions" do
      expect(described_class::INSTRUCTIONS).to include("go_to")
      expect(described_class::INSTRUCTIONS).to include("click")
      expect(described_class::INSTRUCTIONS).to include("screenshot")
    end

    it "is frozen" do
      expect(described_class::INSTRUCTIONS).to be_frozen
    end
  end

  describe ".escape_xpath_string" do
    it "wraps simple strings in single quotes" do
      expect(described_class.escape_xpath_string("hello")).to eq("'hello'")
    end

    it "uses double quotes when string contains single quote" do
      expect(described_class.escape_xpath_string("it's")).to eq("\"it's\"")
    end

    it "uses concat when string contains both quote types" do
      result = described_class.escape_xpath_string("it's \"complex\"")
      expect(result).to include("concat(")
    end
  end

  describe ".save_screenshot_callback" do
    it "returns a callable" do
      callback = described_class.save_screenshot_callback
      expect(callback).to respond_to(:call)
    end
  end
end

RSpec.describe Smolagents::BrowserTools do
  describe ".all" do
    it "returns array of tool instances" do
      tools = described_class.all
      expect(tools).to be_an(Array)
      expect(tools.size).to eq(6)
      expect(tools.map(&:name)).to contain_exactly(
        "go_back", "close_popups", "search_item_ctrl_f",
        "click_element", "go_to", "scroll"
      )
    end
  end

  describe Smolagents::BrowserTools::GoBack do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("go_back")
      expect(tool.description).to include("previous page")
      expect(tool.inputs).to eq({})
    end
  end

  describe Smolagents::BrowserTools::ClosePopups do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("close_popups")
      expect(tool.description).to include("Escape")
    end
  end

  describe Smolagents::BrowserTools::Search do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("search_item_ctrl_f")
      expect(tool.inputs.keys).to contain_exactly(:text, :nth_result)
    end
  end

  describe Smolagents::BrowserTools::Click do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("click_element")
      expect(tool.inputs.keys).to contain_exactly(:text)
    end
  end

  describe Smolagents::BrowserTools::GoTo do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("go_to")
      expect(tool.inputs.keys).to contain_exactly(:url)
    end
  end

  describe Smolagents::BrowserTools::Scroll do
    it "has correct metadata" do
      tool = described_class.new
      expect(tool.name).to eq("scroll")
      expect(tool.inputs.keys).to contain_exactly(:pixels)
    end
  end
end

RSpec.describe Smolagents::ActionStep do
  describe "observations_images" do
    it "supports observations_images field" do
      step = described_class.new(
        step_number: 1,
        observations_images: ["image1.png", "image2.png"]
      )
      expect(step.observations_images).to eq(["image1.png", "image2.png"])
    end

    it "includes image count in to_h" do
      step = described_class.new(
        step_number: 1,
        observations_images: ["a", "b", "c"]
      )
      expect(step.to_h[:observations_images]).to eq(3)
    end

    it "defaults to nil" do
      step = described_class.new(step_number: 1)
      expect(step.observations_images).to be_nil
    end
  end
end
