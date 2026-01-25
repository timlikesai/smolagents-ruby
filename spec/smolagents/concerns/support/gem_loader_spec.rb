require "spec_helper"

RSpec.describe Smolagents::Concerns::GemLoader do
  subject(:loader) { test_class.new }

  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::GemLoader
    end
  end

  describe "#require_gem" do
    context "with available gem" do
      it "requires the gem successfully" do
        expect { loader.require_gem("json") }.not_to raise_error
      end

      it "succeeds silently" do
        result = loader.require_gem("json")
        expect(result).to be true
      end
    end

    context "with missing gem" do
      it "raises LoadError" do
        expect do
          loader.require_gem("nonexistent_gem_that_does_not_exist_12345")
        end.to raise_error(LoadError)
      end

      it "includes gem name in error message" do
        expect do
          loader.require_gem("missing_gem")
        end.to raise_error(LoadError, /missing_gem/)
      end

      it "includes Gemfile suggestion" do
        expect do
          loader.require_gem("missing_gem")
        end.to raise_error(LoadError, /Gemfile/)
      end

      it "includes gem installation syntax" do
        expect do
          loader.require_gem("missing_gem")
        end.to raise_error(LoadError, /gem 'missing_gem'/)
      end
    end

    context "with custom install_name" do
      it "uses install_name in error message" do
        expect do
          loader.require_gem("some_gem", install_name: "better_gem_name")
        end.to raise_error(LoadError, /better_gem_name/)
      end

      it "includes custom name in Gemfile syntax" do
        expect do
          loader.require_gem("some_gem", install_name: "custom_name")
        end.to raise_error(LoadError, /gem 'custom_name'/)
      end
    end

    context "with version constraint" do
      it "includes version in error message" do
        expect do
          loader.require_gem("missing_gem", version: "~> 1.0")
        end.to raise_error(LoadError, /~> 1.0/)
      end

      it "formats version in Gemfile syntax" do
        expect do
          loader.require_gem("missing_gem", version: "~> 2.5")
        end.to raise_error(LoadError, /gem 'missing_gem', '~> 2.5'/)
      end

      it "handles multiple version constraints" do
        expect do
          loader.require_gem("missing_gem", version: ">= 1.0, < 2.0")
        end.to raise_error(LoadError, />= 1.0, < 2.0/)
      end
    end

    context "with custom description" do
      it "uses description in error message" do
        expect do
          loader.require_gem("missing_gem", description: "MyAwesomeLib")
        end.to raise_error(LoadError, /MyAwesomeLib/)
      end

      it "makes error message more readable" do
        expect do
          loader.require_gem("missing_gem", description: "Redis client library")
        end.to raise_error(LoadError, /Redis client library/)
      end
    end

    context "with all options" do
      it "combines all options in error message" do
        expect do
          loader.require_gem(
            "pg_gem",
            install_name: "pg",
            version: "~> 1.5",
            description: "PostgreSQL adapter"
          )
        end.to raise_error(LoadError) do |err|
          msg = err.message
          expect(msg).to include("PostgreSQL adapter")
          expect(msg).to include("pg")
          expect(msg).to include("~> 1.5")
          expect(msg).to include("Gemfile")
        end
      end
    end

    context "integration with actual gems" do
      it "successfully requires json" do
        expect { loader.require_gem("json") }.not_to raise_error
        expect { JSON.parse("{}") }.not_to raise_error
      end

      it "successfully requires yaml" do
        expect { loader.require_gem("yaml") }.not_to raise_error
        expect { YAML.dump({}) }.not_to raise_error
      end

      it "successfully requires set" do
        expect { loader.require_gem("set") }.not_to raise_error
        expect { Set.new([1, 2, 3]) }.not_to raise_error
      end
    end

    context "error message format" do
      it "formats like Gemfile syntax with version" do
        expect do
          loader.require_gem("nonexistent_gem_xyz123", version: "~> 0.5")
        end.to raise_error(LoadError, /gem 'nonexistent_gem_xyz123', '~> 0.5'/)
      end

      it "mentions adding to Gemfile not gem install" do
        expect do
          loader.require_gem("missing_gem")
        end.to raise_error(LoadError, /Gemfile/)
      end

      it "creates copy-paste ready Gemfile syntax" do
        expect do
          loader.require_gem("another_nonexistent_gem_abc789", version: "~> 1.14")
        end.to raise_error(LoadError, /gem 'another_nonexistent_gem_abc789', '~> 1.14'/)
      end
    end

    context "edge cases" do
      it "handles gem names with underscores" do
        expect do
          loader.require_gem("html_parser", description: "HTML parser")
        end.to raise_error(LoadError, /html_parser/)
      end

      it "handles gem names with hyphens" do
        expect do
          loader.require_gem("ruby-openai", install_name: "ruby-openai")
        end.to raise_error(LoadError, /ruby-openai/)
      end

      it "handles complex version specs" do
        expect do
          loader.require_gem("missing", version: ">= 1.0.0, < 2.0.0")
        end.to raise_error(LoadError, />= 1.0.0, < 2.0.0/)
      end

      it "handles very long descriptions" do
        long_desc = "Very comprehensive description of what this gem does and why you need it"
        expect do
          loader.require_gem("missing_gem", description: long_desc)
        end.to raise_error(LoadError, /#{long_desc}/)
      end
    end
  end

  describe "class behavior" do
    it "can be included in a class" do
      klass = Class.new { include Smolagents::Concerns::GemLoader }
      instance = klass.new

      expect { instance.require_gem("json") }.not_to raise_error
    end

    it "can be included in a module" do
      mod = Module.new { include Smolagents::Concerns::GemLoader }
      klass = Class.new { include mod }
      instance = klass.new

      expect { instance.require_gem("json") }.not_to raise_error
    end
  end
end
