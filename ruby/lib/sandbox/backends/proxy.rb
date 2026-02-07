# frozen_string_literal: true

module Sandbox
  module Backends
    class Proxy
      def initialize(base_backend)
        @base_backend = base_backend
      end

      def name
        @base_backend.respond_to?(:name) ? @base_backend.name : 'proxy'
      end

      def method_missing(method, *args, **kwargs, &block)
        return @base_backend.public_send(method, *args, **kwargs, &block) if @base_backend.respond_to?(method)

        super
      end

      def respond_to_missing?(method, include_private = false)
        @base_backend.respond_to?(method, include_private) || super
      end
    end
  end
end
