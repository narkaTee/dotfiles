# frozen_string_literal: true

module Sandbox
  module Backends
    class Hcloud
      def initialize(bash_runner:, command_runner:, sync: false)
        @bash_runner = bash_runner
        @command_runner = command_runner
        @sync = sync
      end

      def backend_start(name, use_pty: false)
        env = {}
        env['SYNC'] = 'true' if @sync
        @bash_runner.call('start_hcloud_sandbox', name, env: env, use_pty: use_pty)
      end

      def backend_stop(name)
        @bash_runner.call('stop_hcloud_sandbox', name)
      end

      def backend_enter(name)
        if ssh_alias_setup?(name)
          @command_runner.exec(['ssh', name])
        else
          ip = server_ip(name)
          raise Sandbox::BackendError, 'Error: Could not determine server IP' if ip.nil? || ip.empty?

          cmd = ['ssh', '-o', 'UserKnownHostsFile=/dev/null', '-o', 'StrictHostKeyChecking=no', "dev@#{ip}"]
          @command_runner.exec(cmd)
        end
      end

      def backend_is_running(name)
        @bash_runner.call('is_hcloud_running', name)
        true
      rescue Sandbox::CommandError
        false
      end

      def backend_get_ssh_port(name)
        @bash_runner.call('get_hcloud_ssh_port', name, capture: true).strip
      end

      def backend_get_ip(name)
        @bash_runner.call('get_hcloud_ip', name, capture: true).strip
      end

      def list
        @bash_runner.call('list_hcloud_sandboxes')
      end

      def backend_stop_all
        @bash_runner.call('stop_all_hcloud_sandboxes')
      end

      def state_dir(name)
        @bash_runner.call('hcloud_state_dir', name, capture: true).strip
      end

      private

      def ssh_alias_setup?(name)
        @bash_runner.call('is_ssh_alias_setup', name)
        true
      rescue Sandbox::CommandError
        false
      end

      def server_ip(name)
        ip = backend_get_ip(name)
        return ip unless ip.empty?

        state_path = state_dir(name)
        ip_file = File.join(state_path, 'server.ip')
        File.exist?(ip_file) ? File.read(ip_file).strip : ''
      end
    end
  end
end
