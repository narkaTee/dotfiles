# frozen_string_literal: true

module Sandbox
  module Backends
    class Container
      attr_writer :proxy_enabled

      def initialize(bash_runner:, command_runner:, proxy: false)
        @bash_runner = bash_runner
        @command_runner = command_runner
        @proxy = proxy
      end

      def backend_start(name, use_pty: false)
        @bash_runner.call('start_container_sandbox', name, env: proxy_env, use_pty: use_pty)
      end

      def backend_stop(name)
        @bash_runner.call('stop_container_sandbox', name, env: proxy_env)
      end

      def backend_enter(name)
        engine = @bash_runner.call('detect_container_engine', capture: true).strip
        raise Sandbox::BackendError, 'Error: Neither podman nor docker found' if engine.empty?

        cmd = [engine, 'exec', '-it', '-e', "TERM=#{ENV.fetch('TERM', 'xterm-256color')}", '-u', 'dev',
               '-w', '/home/dev/workspace', name, 'zsh']
        @command_runner.exec(cmd)
      end

      def backend_is_running(name)
        @bash_runner.call('is_container_running', name)
        true
      rescue Sandbox::CommandError
        false
      end

      def backend_get_ssh_port(name)
        @bash_runner.call('get_container_ssh_port', name, capture: true).strip
      end

      def backend_get_ip(_name)
        'localhost'
      end

      def list
        @bash_runner.call('list_container_sandboxes')
      end

      def backend_stop_all
        @bash_runner.call('stop_all_container_sandboxes')
      end

      private

      def proxy_env
        (@proxy || @proxy_enabled) ? { 'PROXY' => 'true' } : {}
      end
    end
  end
end
