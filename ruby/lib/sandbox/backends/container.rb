# frozen_string_literal: true

module Sandbox
  module Backends
    class Container
      def initialize(runner:, proxy: false)
        @runner = runner
        @proxy = proxy
        env = { 'PROXY' => proxy ? 'true' : 'false', 'BACKEND' => 'container' }
        @backend = BashBackend.new(
          name: 'container',
          source_files: [common_path, backend_path, proxy_path],
          functions: {
            start: 'start_container_sandbox',
            stop: 'stop_container_sandbox',
            is_running: 'is_container_running',
            get_ssh_port: 'get_container_ssh_port',
            get_ip: 'get_container_ip',
            list: 'list_container_sandboxes',
            stop_all: 'stop_all_container_sandboxes'
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
        engine = detect_container_engine
        @runner.exec([
          engine, 'exec', '-it',
          '-e', "TERM=#{ENV.fetch('TERM', 'xterm-256color')}",
          '-u', 'dev',
          '-w', '/home/dev/workspace',
          name,
          'zsh'
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

      def detect_container_engine
        return ENV['CONTAINER_ENGINE'] if ENV['CONTAINER_ENGINE'] && !ENV['CONTAINER_ENGINE'].empty?

        return 'podman' if command_available?('podman')
        return 'docker' if command_available?('docker')

        raise Error, 'Neither podman nor docker found'
      end

      def command_available?(name)
        system("command -v #{name} >/dev/null 2>&1")
      end

      private

      def common_path
        File.join(Dir.home, '.config/lib/bash/sandbox/common')
      end

      def backend_path
        File.join(Dir.home, '.config/lib/bash/sandbox/container-backend')
      end

      def proxy_path
        File.join(Dir.home, '.config/lib/bash/sandbox/proxy-backend')
      end
    end
  end
end
