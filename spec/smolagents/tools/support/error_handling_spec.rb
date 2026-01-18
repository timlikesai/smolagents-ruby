require "spec_helper"

RSpec.describe Smolagents::Tools::Support::ErrorHandling do
  let(:test_class) do
    Class.new do
      include Smolagents::Tools::Support::ErrorHandling
    end
  end

  let(:instance) { test_class.new }

  describe "#with_error_handling" do
    it "returns block result on success" do
      result = instance.with_error_handling { "success" }

      expect(result).to eq("success")
    end

    it "handles Faraday::TimeoutError" do
      result = instance.with_error_handling do
        raise Faraday::TimeoutError, "timed out"
      end

      expect(result).to eq("Request timed out.")
    end

    it "handles Faraday::ConnectionFailed" do
      result = instance.with_error_handling do
        raise Faraday::ConnectionFailed, "refused"
      end

      expect(result).to eq("Connection failed.")
    end

    it "handles generic Faraday::Error with message" do
      result = instance.with_error_handling do
        raise Faraday::Error, "something went wrong"
      end

      expect(result).to eq("HTTP error: something went wrong")
    end

    it "re-raises unknown errors" do
      expect do
        instance.with_error_handling { raise ArgumentError, "bad input" }
      end.to raise_error(ArgumentError, "bad input")
    end

    context "with additional error handlers" do
      it "uses custom error handlers" do
        custom_errors = {
          ArgumentError => "Invalid argument provided."
        }

        result = instance.with_error_handling(custom_errors) do
          raise ArgumentError, "bad"
        end

        expect(result).to eq("Invalid argument provided.")
      end

      it "supports proc handlers" do
        custom_errors = {
          ArgumentError => ->(e) { "Arg error: #{e.message}" }
        }

        result = instance.with_error_handling(custom_errors) do
          raise ArgumentError, "bad input"
        end

        expect(result).to eq("Arg error: bad input")
      end

      it "merges with standard errors" do
        custom_errors = {
          ArgumentError => "Invalid argument."
        }

        result = instance.with_error_handling(custom_errors) do
          raise Faraday::TimeoutError, "timed out"
        end

        expect(result).to eq("Request timed out.")
      end
    end
  end
end
