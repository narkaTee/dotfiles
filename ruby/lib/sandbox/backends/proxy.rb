# frozen_string_literal: true

module Sandbox
  module Backends
    class Proxy
      attr_reader :backend

      def initialize(backend)
        @backend = backend
      end

      def backend_start(name, use_pty: false)
        with_proxy { @backend.backend_start(name, use_pty: use_pty) }
      end

      def backend_stop(name)
        with_proxy { @backend.backend_stop(name) }
      end

      def backend_enter(name)
        @backend.backend_enter(name)
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

      def list
        @backend.list
      end

      def console_socket(name)
        return @backend.console_socket(name) if @backend.respond_to?(:console_socket)

        nil
      end

      private

      def with_proxy
        if @backend.respond_to?(:proxy_enabled=)
          @backend.proxy_enabled = true
          yield
        else
          yield
        end
      ensure
        if @backend.respond_to?(:proxy_enabled=)
          @backend.proxy_enabled = false
        end
      end
    end
  end
end
