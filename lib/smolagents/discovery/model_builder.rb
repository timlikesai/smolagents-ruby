module Smolagents
  module Discovery
    # Builds DiscoveredModel instances from API responses.
    module ModelBuilder
      module_function

      def build(ctx, id:, context_length: nil, state: :available, capabilities: nil, type: nil)
        DiscoveredModel.new(**ctx_attrs(ctx), id:, context_length:, state:, capabilities:, type:)
      end

      def ctx_attrs(ctx)
        { provider: ctx.provider, host: ctx.host, port: ctx.port, tls: ctx.tls, api_key: ctx.api_key }
      end

      def from_lm_studio(ctx, model_data)
        loaded = model_data["loaded_instances"]&.any?
        model_id = loaded ? model_data["loaded_instances"].first["id"] : model_data["key"]

        build(
          ctx,
          id: model_id,
          context_length: model_data["max_context_length"],
          state: loaded ? :loaded : :not_loaded,
          capabilities: extract_capabilities(model_data),
          type: model_data["type"]
        )
      end

      def from_v0(ctx, model_data)
        build(
          ctx,
          id: model_data["id"],
          context_length: model_data["max_context_length"] || model_data["loaded_context_length"],
          state: model_data["state"]&.to_sym || :available,
          capabilities: model_data["capabilities"],
          type: model_data["type"]
        )
      end

      def from_v1(ctx, model_data)
        build(
          ctx,
          id: model_data["id"],
          context_length: extract_context(model_data),
          state: extract_state(model_data)
        )
      end

      def from_native(ctx, model_data)
        build(ctx, id: model_data["name"] || model_data["model"])
      end

      def extract_capabilities(model_data)
        caps = []
        caps << "tool_use" if model_data.dig("capabilities", "trained_for_tool_use")
        caps << "vision" if model_data.dig("capabilities", "vision")
        caps.any? ? caps : nil
      end

      def extract_state(model_data)
        case model_data.dig("status", "value")
        when "loaded" then :loaded
        when "loading" then :loading
        when "unloaded" then :unloaded
        else :available
        end
      end

      def extract_context(model_data)
        args = model_data.dig("status", "args") || []
        ctx_idx = args.index("--ctx-size")
        ctx_idx && args[ctx_idx + 1] ? args[ctx_idx + 1].to_i : nil
      end
    end
  end
end
