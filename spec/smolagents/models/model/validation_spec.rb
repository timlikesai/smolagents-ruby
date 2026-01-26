require "smolagents/models/model"

RSpec.describe Smolagents::Models::Model::Validation do
  let(:model) { Smolagents::Model.new(model_id: "test-model") }

  describe "#validate_required_params" do
    context "when all required parameters are present" do
      it "does not raise an error" do
        expect do
          model.validate_required_params(%i[api_key model_id], { api_key: "key", model_id: "gpt-4" })
        end.not_to raise_error
      end

      it "ignores extra parameters" do
        expect do
          model.validate_required_params(%i[api_key], { api_key: "key", extra: "value", another: 42 })
        end.not_to raise_error
      end

      it "works with empty required list" do
        expect do
          model.validate_required_params([], { api_key: "key" })
        end.not_to raise_error
      end
    end

    context "when required parameters are missing" do
      it "raises ArgumentError with missing parameter name" do
        expect do
          model.validate_required_params(%i[api_key model_id], { api_key: "key" })
        end.to raise_error(ArgumentError, /Missing required parameters: model_id/)
      end

      it "lists all missing parameters" do
        expect do
          model.validate_required_params(%i[api_key model_id timeout], { api_key: "key" })
        end.to raise_error(ArgumentError, /Missing required parameters: model_id, timeout/)
      end

      it "preserves order of missing parameters" do
        expect do
          model.validate_required_params(%i[z a m], {})
        end.to raise_error(ArgumentError, /Missing required parameters: z, a, m/)
      end
    end

    context "with single required parameter" do
      it "passes when parameter is present" do
        expect do
          model.validate_required_params(%i[api_key], { api_key: "secret" })
        end.not_to raise_error
      end

      it "raises when parameter is missing" do
        expect do
          model.validate_required_params(%i[api_key], {})
        end.to raise_error(ArgumentError, /api_key/)
      end
    end

    context "with multiple required parameters" do
      it "passes when all are present" do
        required = %i[api_key model_id api_base temperature max_tokens]
        params = {
          api_key: "key",
          model_id: "gpt-4",
          api_base: "https://api.openai.com",
          temperature: 0.7,
          max_tokens: 200
        }

        expect do
          model.validate_required_params(required, params)
        end.not_to raise_error
      end

      it "raises when some are missing" do
        required = %i[api_key model_id api_base]
        params = { api_key: "key", model_id: "gpt-4" }

        expect do
          model.validate_required_params(required, params)
        end.to raise_error(ArgumentError, /api_base/)
      end
    end

    context "with symbol and string keys" do
      it "matches symbol keys against symbol requirements" do
        expect do
          model.validate_required_params(%i[api_key], { api_key: "key" })
        end.not_to raise_error
      end

      it "requires exact key matching (symbol vs string)" do
        expect do
          model.validate_required_params(%i[api_key], { "api_key" => "key" })
        end.to raise_error(ArgumentError, /api_key/)
      end
    end

    context "with nil and empty values" do
      it "treats nil as a valid value" do
        expect do
          model.validate_required_params(%i[api_key], { api_key: nil })
        end.not_to raise_error
      end

      it "treats empty string as a valid value" do
        expect do
          model.validate_required_params(%i[api_key], { api_key: "" })
        end.not_to raise_error
      end

      it "treats false as a valid value" do
        expect do
          model.validate_required_params(%i[debug], { debug: false })
        end.not_to raise_error
      end

      it "treats zero as a valid value" do
        expect do
          model.validate_required_params(%i[timeout], { timeout: 0 })
        end.not_to raise_error
      end
    end
  end
end
