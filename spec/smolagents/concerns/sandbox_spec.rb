require "spec_helper"

RSpec.describe Smolagents::Concerns::RubySafety, type: :integration do
  describe "integration" do
    describe "RubySafety code validation" do
      let(:validator_class) do
        Class.new { include Smolagents::Concerns::RubySafety }
      end
      let(:validator) { validator_class.new }

      it "validates safe code" do
        result = validator.validate_ruby_code("x = 1 + 2")
        expect(result.valid?).to be true
      end

      it "rejects dangerous code" do
        result = validator.validate_ruby_code("system('rm -rf /')")
        expect(result.valid?).to be false
      end

      it "raises on dangerous code with bang method" do
        expect { validator.validate_ruby_code!("eval('code')") }
          .to raise_error(Smolagents::InterpreterError)
      end
    end

    describe "SandboxMethods injection" do
      it "defines methods on a class" do
        sandbox_class = Class.new do
          def initialize
            @output_buffer = StringIO.new
            @variables = {}
            @tools = {}
          end
        end

        Smolagents::Concerns::SandboxMethods.define_on(sandbox_class)
        instance = sandbox_class.new

        expect(instance).to respond_to(:puts)
        expect(instance).to respond_to(:tools)
        expect(instance).to respond_to(:vars)
        expect(instance).to respond_to(:budget)
      end
    end
  end
end
