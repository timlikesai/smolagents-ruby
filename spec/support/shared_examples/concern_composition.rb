# Shared examples for composable concerns.
#
# Usage:
#   it_behaves_like "composable concerns" do
#     let(:concerns) { [ConcernA, ConcernB] }
#     let(:host_class) { Class.new }
#   end
#
#   it_behaves_like "a concern with public interface" do
#     let(:concern) { MyConcern }
#     let(:expected_methods) { %i[execute validate] }
#     let(:host_instance) { Class.new { include MyConcern }.new }
#   end

RSpec.shared_examples "composable concerns" do
  let(:composed_class) do
    klass = host_class
    concerns.each { |c| klass.include(c) }
    klass
  end

  it "includes all concerns without error" do
    expect { composed_class }.not_to raise_error
  end

  it "includes all concerns in the ancestor chain" do
    concerns.each do |concern|
      expect(composed_class.ancestors).to include(concern)
    end
  end

  it "has no method name conflicts across concerns" do
    method_owners = {}
    conflicts = []
    concerns.each do |concern|
      next unless concern.respond_to?(:instance_methods)

      concern.instance_methods(false).each do |method_name|
        conflicts << ":#{method_name} (#{method_owners[method_name]} vs #{concern})" if method_owners[method_name]

        method_owners[method_name] = concern
      end
    end
    expect(conflicts).to be_empty, "Method conflicts: #{conflicts.join(", ")}"
  end

  it "can instantiate the composed class" do
    expect { composed_class.new }.not_to raise_error
  end
end

RSpec.shared_examples "a concern with public interface" do
  it "provides all expected methods" do
    expected_methods.each do |method_name|
      expect(host_instance).to respond_to(method_name)
    end
  end

  it "is a module" do
    expect(concern).to be_a(Module)
  end
end
