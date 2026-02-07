# frozen_string_literal: true

module Sandbox
  module Backends
    class Kvm
      attr_writer :proxy_enabled

      def initialize(bash_runner:, command_runner:, proxy: false)
        @bash_runner = bash_runner
        @command_runner = command_runner
        @proxy = proxy
      end

      def backend_start(name, use_pty: false)
        @bash_runner.call('start_kvm_sandbox', name, env: proxy_env, use_pty: use_pty)
      end

      def backend_stop(name)
        @bash_runner.call('stop_kvm_sandbox', name, env: proxy_env)
      end

      def backend_enter(name)
        port = backend_get_ssh_port(name)
        raise Sandbox::BackendError, 'Error: Could not determine SSH port' if port.empty?

        cmd = ['ssh', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no',
               '-p', port, 'dev@localhost']
        @command_runner.exec(cmd)
      end

      def backend_is_running(name)
        @bash_runner.call('is_kvm_running', name)
        true
      rescue Sandbox::CommandError
        false
      end

      def backend_get_ssh_port(name)
        @bash_runner.call('get_kvm_ssh_port', name, capture: true).strip
      end

      def backend_get_ip(name)
        @bash_runner.call('get_kvm_ip', name, capture: true).strip
      end

      def list
        @bash_runner.call('list_kvm_sandboxes')
      end

      def backend_stop_all
        @bash_runner.call('stop_all_kvm_sandboxes')
      end

      def console_socket(name)
        @bash_runner.call('kvm_console_socket', name, capture: true).strip
      end

      private

      def proxy_env
        (@proxy || @proxy_enabled) ? { 'PROXY' => 'true' } : {}
      end
    end
  end
end
