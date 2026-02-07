# frozen_string_literal: true

module Sandbox
  module Backends
    class Kvm
      def initialize(runner:, proxy: false)
        @runner = runner
        @proxy = proxy
        env = { 'PROXY' => proxy ? 'true' : 'false', 'BACKEND' => 'kvm' }
        @backend = BashBackend.new(
          name: 'kvm',
          source_files: [common_path, backend_path, proxy_path],
          functions: {
            start: 'start_kvm_sandbox',
            stop: 'stop_kvm_sandbox',
            is_running: 'is_kvm_running',
            get_ssh_port: 'get_kvm_ssh_port',
            get_ip: 'get_kvm_ip',
            list: 'list_kvm_sandboxes',
            stop_all: 'stop_all_kvm_sandboxes'
          },
          runner: runner,
          env: env
        )
      end

      def validate_requirements
        raise Error, 'KVM not available (no /dev/kvm)' unless File.exist?('/dev/kvm')
        raise Error, 'KVM not writeable for this user' unless File.writable?('/dev/kvm')
        raise Error, 'qemu-system-x86_64 not found' unless command_available?('qemu-system-x86_64')
      end

      def backend_start(name, pty: false)
        @backend.backend_start(name, pty: pty)
      end

      def backend_stop(name)
        @backend.backend_stop(name)
      end

      def backend_enter(name)
        port = backend_get_ssh_port(name)
        raise Error, 'Could not determine SSH port' if port.nil? || port.empty?

        @runner.exec([
          'ssh',
          '-o', 'UserKnownHostsFile=/dev/null',
          '-o', 'StrictHostKeyChecking=no',
          '-p', port.to_s,
          'dev@localhost'
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
        return self if @proxy

        self.class.new(runner: @runner, proxy: true)
      end

      private

      def command_available?(name)
        system("command -v #{name} >/dev/null 2>&1")
      end

      def common_path
        File.join(Dir.home, '.config/lib/bash/sandbox/common')
      end

      def backend_path
        File.join(Dir.home, '.config/lib/bash/sandbox/kvm-backend')
      end

      def proxy_path
        File.join(Dir.home, '.config/lib/bash/sandbox/proxy-backend')
      end
    end
  end
end
