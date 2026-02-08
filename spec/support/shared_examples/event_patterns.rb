# Shared examples for event-emitting and event-consuming concerns.
#
# Usage:
#   it_behaves_like "an event-emitting concern" do
#     let(:emitter) { test_instance }
#     let(:expected_events) { [:step_completed, :tool_call_completed] }
#   end
#
#   it_behaves_like "an event consumer" do
#     let(:consumer) { test_instance }
#     let(:subscribed_events) { [:step_completed] }
#   end

RSpec.shared_examples "an event-emitting concern" do
  it "includes Events::Emitter" do
    expect(emitter.class.ancestors).to include(Smolagents::Events::Emitter)
  end

  it "responds to :emit" do
    expect(emitter).to respond_to(:emit)
  end

  it "responds to :emit!" do
    expect(emitter).to respond_to(:emit!)
  end

  it "can emit events to a connected queue" do
    queue = Thread::Queue.new
    emitter.connect_to(queue)

    expected_events.each do |event_name|
      emitter.emit(event_name)
    end

    expect(queue.size).to eq(expected_events.size)
  end

  it "emits events with id and created_at" do
    queue = Thread::Queue.new
    emitter.connect_to(queue)

    emitter.emit(expected_events.first)
    event = queue.pop(true)

    expect(event).to respond_to(:id)
    expect(event).to respond_to(:created_at)
    expect(event.id).to be_a(String)
    expect(event.created_at).to be_a(Time)
  end

  it "emits events with monotonic sequence numbers" do
    queue = Thread::Queue.new
    emitter.connect_to(queue)

    emitter.emit(expected_events.first)
    emitter.emit(expected_events.first)

    first_event = queue.pop(true)
    second_event = queue.pop(true)
    expect(second_event.sequence).to be > first_event.sequence
  end
end

RSpec.shared_examples "an event consumer" do
  it "includes Events::Consumer" do
    expect(consumer.class.ancestors).to include(Smolagents::Events::Consumer)
  end

  it "responds to :on" do
    expect(consumer).to respond_to(:on)
  end

  it "responds to :consume" do
    expect(consumer).to respond_to(:consume)
  end

  it "receives emitted events via subscription" do
    received = []
    subscribed_events.each do |event_type|
      consumer.on(event_type) { |e| received << e }
    end

    event_class = Smolagents::Events::Mappings.resolve(subscribed_events.first)
    event = event_class.create
    consumer.consume(event)

    expect(received.size).to eq(1)
    expect(received.first).to eq(event)
  end
end
