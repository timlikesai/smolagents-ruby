module Smolagents
  module Servers
    class LlamaCpp
      # Model info returned from the server.
      ModelInfo = Data.define(:id, :status, :context_size, :failed, :preset) do
        def loaded? = status == "loaded"
        def unloaded? = status == "unloaded"
        def loading? = status == "loading"
        def failed? = failed == true
        def ready? = loaded? && !failed?
      end

      # Slot info for a loaded model.
      SlotInfo = Data.define(:id, :context_size, :speculative, :processing)
    end
  end
end
