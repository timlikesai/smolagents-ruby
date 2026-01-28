module Smolagents
  module Telemetry
    # System health checks for Smolagents runtime.
    #
    # Provides diagnostic checks for configuration, toolkits, and memory.
    # Used to verify system readiness before running agents.
    #
    # @example Basic health check
    #   status = SmolagentsHealthCheck.check
    #   status[:healthy]  #=> true
    #   status[:checks].keys  #=> [:configuration, :tools, :memory]
    #
    # @example Individual checks
    #   SmolagentsHealthCheck.check_configuration
    #   #=> { frozen: false, max_steps: 20, log_level: :info }
    #
    #   SmolagentsHealthCheck.check_tools
    #   #=> { toolkit_count: 4, available_toolkits: [:search, :web, :data, :research] }
    #
    #   SmolagentsHealthCheck.check_memory
    #   #=> { heap_slots: 50000, gc_count: 10, healthy: true }
    module SmolagentsHealthCheck
      MEMORY_THRESHOLD = 10_000

      class << self
        # Runs all health checks and returns combined status.
        #
        # @return [Hash] Combined health check result with :healthy and :checks keys
        def check
          checks = {
            configuration: check_configuration,
            tools: check_tools,
            memory: check_memory
          }

          healthy = checks.values.all? do |result|
            result.is_a?(Hash) && result.fetch(:healthy, true)
          end

          { healthy:, checks: }
        end

        # Checks configuration status.
        #
        # @return [Hash] Configuration check with frozen status and key settings
        def check_configuration
          config = Smolagents.configuration

          {
            frozen: config.frozen?,
            max_steps: config.max_steps,
            log_level: config.log_level
          }
        end

        # Checks available toolkits.
        #
        # @return [Hash] Toolkit check with count and list of available toolkits
        def check_tools
          toolkits = Smolagents::Toolkits.names

          {
            toolkit_count: toolkits.size,
            available_toolkits: toolkits
          }
        end

        # Checks memory and GC status.
        #
        # @return [Hash] Memory check with heap slots, GC count, and health status
        def check_memory
          gc_stats = GC.stat
          heap_slots = gc_stats[:heap_live_slots] || gc_stats[:heap_available_slots] || 0
          gc_count = gc_stats[:count] || GC.count

          {
            heap_slots:,
            gc_count:,
            healthy: heap_slots > MEMORY_THRESHOLD
          }
        end
      end
    end
  end
end
