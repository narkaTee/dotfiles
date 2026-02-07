# frozen_string_literal: true

module Sandbox
  class Error < StandardError; end
  class BackendError < Error; end
  class BackendConflictError < Error; end
  class BackendNotRunningError < Error; end
  class MissingBackendError < Error; end
  class CommandError < Error
    attr_reader :status, :stdout, :stderr

    def initialize(message, status:, stdout: nil, stderr: nil)
      super(message)
      @status = status
      @stdout = stdout
      @stderr = stderr
    end
  end
end

require_relative 'sandbox/name'
require_relative 'sandbox/connection_info'
require_relative 'sandbox/spinner'
require_relative 'sandbox/command_runner'
require_relative 'sandbox/bash_runner'
require_relative 'sandbox/backend'
require_relative 'sandbox/ssh_config'
require_relative 'sandbox/backend_selector'
require_relative 'sandbox/backends/container'
require_relative 'sandbox/backends/kvm'
require_relative 'sandbox/backends/hcloud'
require_relative 'sandbox/backends/proxy'
require_relative 'sandbox/cli'
