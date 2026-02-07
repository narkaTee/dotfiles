# frozen_string_literal: true

module Sandbox
  module Backend
    REQUIRED_METHODS = %i[
      backend_start
      backend_stop
      backend_enter
      backend_is_running
      backend_get_ssh_port
      backend_get_ip
    ].freeze

    def self.ensure!(backend)
      missing = REQUIRED_METHODS.reject { |method| backend.respond_to?(method) }
      return if missing.empty?

      raise Sandbox::BackendError, "Backend #{backend.class} missing methods: #{missing.join(', ')}"
    end
  end
end
