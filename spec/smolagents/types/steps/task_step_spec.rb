require "spec_helper"

RSpec.describe Smolagents::Types::TaskStep do
  let(:step) { described_class.new(task: "Calculate 2+2") }

  it_behaves_like "a step type", message_count: 1 do
    let(:step) { described_class.new(task: "Do something") }
  end

  describe ".new" do
    it "creates a task step with task" do
      result = described_class.new(task: "Find information")
      expect(result.task).to eq("Find information")
    end

    it "defaults task_images to nil" do
      result = described_class.new(task: "Simple task")
      expect(result.task_images).to be_nil
    end

    it "accepts task_images array" do
      result = described_class.new(task: "Describe images", task_images: ["/path/to/image.jpg"])
      expect(result.task_images).to eq(["/path/to/image.jpg"])
    end

    it "accepts multiple images" do
      images = ["/image1.png", "/image2.png", "https://example.com/image.jpg"]
      result = described_class.new(task: "Compare images", task_images: images)
      expect(result.task_images).to eq(images)
    end
  end

  describe "#to_h" do
    it "returns hash with task" do
      expect(step.to_h).to eq({ task: "Calculate 2+2" })
    end

    it "excludes nil task_images" do
      expect(step.to_h).not_to have_key(:task_images)
    end

    it "includes task_images count when present" do
      with_images = described_class.new(task: "Describe", task_images: ["/a.jpg", "/b.jpg"])
      expect(with_images.to_h).to eq({ task: "Describe", task_images: 2 })
    end

    it "returns 0 for empty task_images array" do
      with_empty = described_class.new(task: "Empty", task_images: [])
      expect(with_empty.to_h).to eq({ task: "Empty", task_images: 0 })
    end
  end

  describe "#to_messages" do
    it "returns array with single user message" do
      messages = step.to_messages
      expect(messages.size).to eq(1)
    end

    it "creates a user role ChatMessage" do
      message = step.to_messages.first
      expect(message).to be_a(Smolagents::ChatMessage)
      expect(message.role).to eq(Smolagents::MessageRole::USER)
    end

    it "includes the task as content" do
      message = step.to_messages.first
      expect(message.content).to eq("Calculate 2+2")
    end

    context "without images" do
      it "creates message with nil images" do
        message = step.to_messages.first
        expect(message.images).to be_nil
      end
    end

    context "with images" do
      let(:step_with_images) do
        described_class.new(task: "Describe this", task_images: ["/photo.jpg"])
      end

      it "includes images in the message" do
        message = step_with_images.to_messages.first
        expect(message.images).to eq(["/photo.jpg"])
      end
    end

    context "with empty images array" do
      let(:step_empty_images) do
        described_class.new(task: "No images", task_images: [])
      end

      it "sets images to nil for empty array" do
        message = step_empty_images.to_messages.first
        expect(message.images).to be_nil
      end
    end

    it "ignores any options passed" do
      messages = step.to_messages(summary_mode: true)
      expect(messages.size).to eq(1)
      expect(messages.first.content).to eq("Calculate 2+2")
    end
  end

  describe "#deconstruct_keys" do
    it "returns hash for pattern matching" do
      result = step.deconstruct_keys(nil)
      expect(result[:task]).to eq("Calculate 2+2")
    end

    it "ignores keys argument" do
      result = step.deconstruct_keys([:task])
      expect(result).to eq({ task: "Calculate 2+2" })
    end
  end

  describe "pattern matching" do
    it "matches on task" do
      result = case step
               in { task: t }
                 t
               end

      expect(result).to eq("Calculate 2+2")
    end

    it "allows conditional matching" do
      result = case step
               in { task: /Calculate/ } then "math task"
               in { task: /Search/ } then "search task"
               else "other task"
               end

      expect(result).to eq("math task")
    end

    it "matches on task_images count" do
      with_images = described_class.new(task: "Describe", task_images: ["/a.jpg", "/b.jpg"])

      result = case with_images.to_h
               in { task_images: 2 } then "two images"
               in { task_images: Integer } then "has images"
               else "no images"
               end

      expect(result).to eq("two images")
    end
  end
end
