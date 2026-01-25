require "spec_helper"

RSpec.describe Smolagents::Security::Allowlists do
  describe "DANGEROUS_METHODS" do
    subject(:methods) { described_class::DANGEROUS_METHODS }

    it "is a frozen Set" do
      expect(methods).to be_a(Set)
      expect(methods).to be_frozen
    end

    it "includes code execution methods" do
      expect(methods).to include("eval", "instance_eval", "class_eval", "module_eval")
    end

    it "includes shell execution methods" do
      expect(methods).to include("system", "exec", "spawn")
    end

    it "includes process control methods" do
      expect(methods).to include("fork", "exit", "exit!", "abort")
    end

    it "includes file I/O methods" do
      expect(methods).to include("open")
    end

    it "includes require methods" do
      expect(methods).to include("require", "require_relative", "load", "autoload")
    end

    it "includes metaprogramming methods" do
      expect(methods).to include("send", "__send__", "public_send", "method", "define_method")
    end

    it "includes constant manipulation methods" do
      expect(methods).to include("const_get", "const_set", "remove_const")
    end

    it "includes variable manipulation methods" do
      expect(methods).to include("instance_variable_get", "instance_variable_set", "class_variable_get",
                                 "class_variable_set", "remove_class_variable", "remove_instance_variable")
    end

    it "includes binding and ObjectSpace" do
      expect(methods).to include("ObjectSpace", "binding")
    end

    it "includes signal handling" do
      expect(methods).to include("trap", "at_exit")
    end
  end

  describe "DANGEROUS_CONSTANTS" do
    subject(:constants) { described_class::DANGEROUS_CONSTANTS }

    it "is a frozen Set" do
      expect(constants).to be_a(Set)
      expect(constants).to be_frozen
    end

    it "includes file system constants" do
      expect(constants).to include("File", "IO", "Dir", "FileUtils", "Pathname")
    end

    it "includes process control constants" do
      expect(constants).to include("Process", "Thread", "Signal")
    end

    it "includes networking constants" do
      expect(constants).to include("Socket", "TCPSocket", "UDPSocket", "BasicSocket")
    end

    it "includes environment access constants" do
      expect(constants).to include("ENV", "ARGV", "ARGF")
    end

    it "includes introspection constants" do
      expect(constants).to include("ObjectSpace", "Marshal", "Kernel")
    end

    it "includes platform constants" do
      expect(constants).to include("RUBY_PLATFORM", "RUBY_VERSION", "DATA")
    end
  end

  describe "DANGEROUS_PATTERNS" do
    subject(:patterns) { described_class::DANGEROUS_PATTERNS }

    it "is a frozen Array" do
      expect(patterns).to be_an(Array)
      expect(patterns).to be_frozen
    end

    it "matches backtick execution" do
      expect(patterns.any? { |p| "`ls`" =~ p }).to be true
    end

    it "matches %x[] execution" do
      expect(patterns.any? { |p| "%x[ls]" =~ p }).to be true
    end

    it "matches %x{} execution" do
      expect(patterns.any? { |p| "%x{ls}" =~ p }).to be true
    end

    it "matches %x() execution" do
      expect(patterns.any? { |p| "%x(ls)" =~ p }).to be true
    end

    it "is an array of Regexp objects" do
      expect(patterns).to all(be_a(Regexp))
    end
  end

  describe "DANGEROUS_IMPORTS" do
    subject(:imports) { described_class::DANGEROUS_IMPORTS }

    it "is a frozen Array" do
      expect(imports).to be_an(Array)
      expect(imports).to be_frozen
    end

    it "includes networking imports" do
      expect(imports).to include("net/http", "open-uri", "socket")
    end

    it "includes file utilities" do
      expect(imports).to include("FileUtils")
    end

    it "contains only string elements" do
      expect(imports).to all(be_a(String))
    end
  end

  describe "IDENTIFIER_TYPES" do
    subject(:types) { described_class::IDENTIFIER_TYPES }

    it "is a frozen Array" do
      expect(types).to be_an(Array)
      expect(types).to be_frozen
    end

    it "includes @ident symbol" do
      expect(types).to include(:@ident)
    end

    it "includes @const symbol" do
      expect(types).to include(:@const)
    end

    it "contains exactly 2 elements" do
      expect(types.size).to eq(2)
    end
  end

  describe "MAX_AST_DEPTH" do
    it "is set to 100" do
      expect(described_class::MAX_AST_DEPTH).to eq(100)
    end

    it "is an integer" do
      expect(described_class::MAX_AST_DEPTH).to be_an(Integer)
    end
  end
end
