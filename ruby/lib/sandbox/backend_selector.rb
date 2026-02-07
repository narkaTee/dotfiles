# frozen_string_literal: true

module Sandbox
  class BackendSelector
    def initialize(backends:, sandbox_name:)
      @backends = backends
      @sandbox_name = sandbox_name
    end

    def detect_running_backend
      running = @backends.select { |_name, backend| backend.backend_is_running(@sandbox_name) }
      return nil if running.empty?
      if running.size > 1
        raise Sandbox::BackendConflictError, 'ERROR: Multiple backends running'
      end

      running.keys.first
    end

    def select_backend(explicit_backend)
      return explicit_backend if explicit_backend

      detect_running_backend || 'container'
    end
  end
end
