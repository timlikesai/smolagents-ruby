# Compression concern registrations.
module Smolagents
  module Concerns
    Registry.tap do |r|
      # === Compression ===
      r.register :compression_strategy,
                 Smolagents::Concerns::Compression::Strategy,
                 category: :compression,
                 provides: %i[should_compress? compress estimate_quality],
                 description: "Base interface for compression strategies"

      r.register :compression_model_based,
                 Smolagents::Concerns::Compression::ModelBased,
                 category: :compression,
                 dependencies: %i[events_emitter],
                 provides: %i[should_compress? compress estimate_quality],
                 description: "Model-based compression using LLM summarization"
    end
  end
end
