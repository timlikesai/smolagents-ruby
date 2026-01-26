require "spec_helper"

RSpec.describe Smolagents::Concerns::Registry do
  # Use explicit class reference because `described_class` changes in nested describe blocks
  let(:registry) { Smolagents::Concerns::Registry } # rubocop:disable RSpec/DescribedClass

  # Save and restore registry state for each test to avoid affecting other tests
  around do |example|
    saved = registry.concerns.dup
    registry.reset!
    example.run
  ensure
    registry.reset!
    saved.each { |name, info| registry.concerns[name] = info }
  end

  describe Smolagents::Concerns::Registry::ConcernInfo do
    subject(:info) do
      described_class.new(
        name: :test_concern,
        module_path: "Smolagents::Concerns::TestConcern",
        dependencies: %i[dep_a dep_b],
        provides: %i[method_a method_b],
        category: :agents,
        description: "A test concern"
      )
    end

    it "is a Data.define immutable type" do
      expect(described_class.ancestors).to include(Data)
    end

    it "exposes all attributes" do
      expect(info.name).to eq(:test_concern)
      expect(info.module_path).to eq("Smolagents::Concerns::TestConcern")
      expect(info.dependencies).to eq(%i[dep_a dep_b])
      expect(info.provides).to eq(%i[method_a method_b])
      expect(info.category).to eq(:agents)
      expect(info.description).to eq("A test concern")
    end

    it "converts to hash" do
      hash = info.to_h
      expect(hash).to eq(
        name: :test_concern,
        module_path: "Smolagents::Concerns::TestConcern",
        dependencies: %i[dep_a dep_b],
        provides: %i[method_a method_b],
        category: :agents,
        description: "A test concern"
      )
    end

    it "supports pattern matching via deconstruct_keys" do
      result = case info
               in { name:, category: :agents }
                 "Agent: #{name}"
               else
                 "Other"
               end
      expect(result).to eq("Agent: test_concern")
    end
  end

  describe ".register" do
    let(:test_module) do
      Module.new do
        def self.name = "Smolagents::Concerns::TestModule"
        def test_method = true # rubocop:disable Naming/PredicateMethod -- test fixture
      end
    end

    it "registers a concern with metadata" do
      info = described_class.register(
        :test_module,
        test_module,
        category: :tools,
        provides: %i[test_method],
        description: "A test module"
      )

      expect(info).to be_a(Smolagents::Concerns::Registry::ConcernInfo)
      expect(info.name).to eq(:test_module)
      expect(info.category).to eq(:tools)
    end

    it "extracts provides from module if not specified" do
      info = described_class.register(:auto_extract, test_module, category: :tools)
      expect(info.provides).to include(:test_method)
    end

    it "stores concern in registry" do
      described_class.register(:stored, test_module)
      expect(described_class[:stored]).not_to be_nil
    end

    it "allows empty dependencies" do
      info = described_class.register(:no_deps, test_module)
      expect(info.dependencies).to eq([])
    end

    it "defaults to :general category" do
      info = described_class.register(:general, test_module)
      expect(info.category).to eq(:general)
    end
  end

  describe ".[]" do
    let(:test_module) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:known_concern, test_module, category: :agents)
    end

    it "returns info for known concern" do
      info = described_class[:known_concern]
      expect(info).to be_a(Smolagents::Concerns::Registry::ConcernInfo)
      expect(info.category).to eq(:agents)
    end

    it "returns nil for unknown concern" do
      expect(described_class[:unknown]).to be_nil
    end
  end

  describe ".all" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:concern_a, mod)
      described_class.register(:concern_b, mod)
    end

    it "returns all registered concern names" do
      expect(described_class.all).to contain_exactly(:concern_a, :concern_b)
    end
  end

  describe ".by_category" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:agent_one, mod, category: :agents)
      described_class.register(:agent_two, mod, category: :agents)
      described_class.register(:tool_one, mod, category: :tools)
    end

    it "groups concerns by category" do
      groups = described_class.by_category
      expect(groups[:agents].map(&:name)).to contain_exactly(:agent_one, :agent_two)
      expect(groups[:tools].map(&:name)).to contain_exactly(:tool_one)
    end
  end

  describe ".in_category" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:agent, mod, category: :agents)
      described_class.register(:tool, mod, category: :tools)
    end

    it "returns concerns in specified category" do
      agents = described_class.in_category(:agents)
      expect(agents.map(&:name)).to eq([:agent])
    end
  end

  describe ".dependencies_for" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      # Build a dependency chain: c -> b -> a
      described_class.register(:a, mod)
      described_class.register(:b, mod, dependencies: [:a])
      described_class.register(:c, mod, dependencies: [:b])
    end

    it "returns transitive dependencies" do
      deps = described_class.dependencies_for(:c)
      expect(deps).to contain_exactly(:b, :a)
    end

    it "returns empty for concern with no dependencies" do
      deps = described_class.dependencies_for(:a)
      expect(deps).to eq([])
    end

    it "returns empty for unknown concern" do
      deps = described_class.dependencies_for(:unknown)
      expect(deps).to eq([])
    end
  end

  describe ".dependents_of" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:base, mod)
      described_class.register(:dep_a, mod, dependencies: [:base])
      described_class.register(:dep_b, mod, dependencies: [:base])
      described_class.register(:other, mod)
    end

    it "returns concerns that depend on given concern" do
      dependents = described_class.dependents_of(:base)
      expect(dependents).to contain_exactly(:dep_a, :dep_b)
    end

    it "returns empty for concern with no dependents" do
      dependents = described_class.dependents_of(:other)
      expect(dependents).to eq([])
    end
  end

  describe ".standalone" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:standalone_a, mod)
      described_class.register(:standalone_b, mod)
      described_class.register(:dependent, mod, dependencies: [:standalone_a])
    end

    it "returns concerns with no dependencies" do
      standalone = described_class.standalone
      expect(standalone).to contain_exactly(:standalone_a, :standalone_b)
    end
  end

  describe ".dependent" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:standalone, mod)
      described_class.register(:dependent_a, mod, dependencies: [:standalone])
      described_class.register(:dependent_b, mod, dependencies: [:standalone])
    end

    it "returns concerns with dependencies" do
      dependent = described_class.dependent
      expect(dependent).to contain_exactly(:dependent_a, :dependent_b)
    end
  end

  describe ".graph" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:root, mod)
      described_class.register(:middle, mod, dependencies: [:root])
      described_class.register(:leaf, mod, dependencies: [:middle])
    end

    it "returns dependency graph with both directions" do
      graph = described_class.graph

      expect(graph[:root]).to eq(depends_on: [], depended_by: [:middle])
      expect(graph[:middle]).to eq(depends_on: [:root], depended_by: [:leaf])
      expect(graph[:leaf]).to eq(depends_on: [:middle], depended_by: [])
    end
  end

  describe ".validate" do
    let(:mod) { Module.new { def self.name = "Test" } }

    before do
      described_class.register(:valid, mod)
      described_class.register(:missing_dep, mod, dependencies: [:nonexistent])
    end

    it "returns missing dependencies by concern" do
      missing = described_class.validate
      expect(missing[:missing_dep]).to eq([:nonexistent])
    end

    it "excludes concerns with all dependencies present" do
      missing = described_class.validate
      expect(missing).not_to have_key(:valid)
    end
  end

  describe ".documentation" do
    let(:mod) { Module.new { def self.name = "Test::Module" } }

    before do
      described_class.register(:agents_concern, mod,
                               category: :agents,
                               provides: %i[run execute],
                               description: "An agent concern")
      described_class.register(:tools_concern, mod,
                               category: :tools,
                               provides: %i[call],
                               dependencies: [:agents_concern],
                               description: "A tool concern")
    end

    it "generates markdown documentation" do
      docs = described_class.documentation
      expect(docs).to include("## Agents")
      expect(docs).to include("## Tools")
      expect(docs).to include("### agents_concern")
      expect(docs).to include("An agent concern")
      expect(docs).to include("**Provides:** run, execute")
    end

    it "includes dependency information" do
      docs = described_class.documentation
      expect(docs).to include("**Dependencies:** agents_concern")
    end
  end

  describe ".reset!" do
    let(:mod) { Module.new { def self.name = "Test" } }

    it "clears all registered concerns" do
      described_class.register(:to_clear, mod)
      expect(described_class.all).not_to be_empty

      described_class.reset!
      expect(described_class.all).to be_empty
    end
  end

  describe "thread safety" do
    let(:mod) { Module.new { def self.name = "Test" } }

    it "handles concurrent registrations" do
      threads = Array.new(10) do |i|
        Thread.new { described_class.register(:"concurrent_#{i}", mod) }
      end
      threads.each(&:join)

      expect(described_class.all.size).to eq(10)
    end
  end
end

# rubocop:disable RSpec/DescribeClass -- testing module-level DSL
RSpec.describe "Smolagents concern DSL methods" do
  describe "Smolagents.concerns" do
    it "returns all registered concern names" do
      expect(Smolagents.concerns).to be_an(Array)
      expect(Smolagents.concerns).to include(:react_loop, :planning, :circuit_breaker)
    end
  end

  describe "Smolagents.concern" do
    it "returns info for known concern" do
      info = Smolagents.concern(:react_loop)
      expect(info).to be_a(Smolagents::Concerns::Registry::ConcernInfo)
      expect(info.category).to eq(:agents)
    end

    it "returns nil for unknown concern" do
      expect(Smolagents.concern(:nonexistent)).to be_nil
    end
  end

  describe "Smolagents.concern_docs" do
    it "returns markdown documentation" do
      docs = Smolagents.concern_docs
      expect(docs).to be_a(String)
      expect(docs).to include("## Agents")
      expect(docs).to include("## Resilience")
    end
  end

  describe "Smolagents.concern_graph" do
    it "returns the dependency graph" do
      graph = Smolagents.concern_graph
      expect(graph).to be_a(Hash)
      expect(graph[:resilience][:depends_on]).to include(:circuit_breaker, :rate_limiter)
    end
  end

  describe "Smolagents.concerns_by_category" do
    it "groups concerns by category" do
      by_cat = Smolagents.concerns_by_category
      expect(by_cat.keys).to include(:agents, :resilience, :tools)
      expect(by_cat[:agents].map(&:name)).to include(:react_loop, :planning)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
