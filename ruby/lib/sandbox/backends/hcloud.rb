# frozen_string_literal: true

module Sandbox
  module Backends
    class Hcloud
      def initialize(runner:, ssh_alias:)
        @runner = runner
        @ssh_alias = ssh_alias
        env = { 'BACKEND' => 'hcloud' }
        @backend = BashBackend.new(
          name: 'hcloud',
          source_files: [common_path, backend_path],
          functions: {
            start: 'start_hcloud_sandbox',
            stop: 'stop_hcloud_sandbox',
            is_running: 'is_hcloud_running',
            get_ssh_port: 'get_hcloud_ssh_port',
            get_ip: 'get_hcloud_ip',
            list: 'list_hcloud_sandboxes',
            stop_all: 'stop_all_hcloud_sandboxes'
          },
          runner: runner,
          env: env
        )
      end

      def backend_start(name, pty: false)
        @backend.backend_start(name, pty: pty)
      end

      def backend_stop(name)
        @backend.backend_stop(name)
      end

      def backend_enter(name)
        if @ssh_alias.configured?(name)
          @runner.exec(['ssh', name])
          return
        end

        ip = backend_get_ip(name)
        raise Error, 'Could not determine server IP' if ip.nil? || ip.empty?

        @runner.exec([
          'ssh',
          '-o', 'UserKnownHostsFile=/dev/null',
          '-o', 'StrictHostKeyChecking=no',
          "dev@#{ip}"
        ])
      end

      def backend_is_running(name)
        @backend.backend_is_running(name)
      end

      def backend_get_ssh_port(name)
        @backend.backend_get_ssh_port(name)
      end

      def backend_get_ip(name)
        @backend.backend_get_ip(name)
      end

      def name
        @backend.name
      end

      def list
        @backend.list
      end

      def stop_all
        @backend.stop_all
      end

      def with_proxy
        self
      end

      private

      def common_path
        File.join(Dir.home, '.config/lib/bash/sandbox/common')
      end

      def backend_path
        File.join(Dir.home, '.config/lib/bash/sandbox/hcloud-backend')
      end
    end
  end
end
