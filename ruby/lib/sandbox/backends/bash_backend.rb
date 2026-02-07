# frozen_string_literal: true

require 'shellwords'

module Sandbox
  module Backends
    class BashBackend
      attr_reader :name

      def initialize(name:, source_files:, functions:, runner:, env: {})
        @name = name
        @source_files = source_files
        @functions = functions
        @runner = runner
        @env = env
      end

      def backend_start(sandbox_name, pty: false)
        run_function(@functions.fetch(:start), sandbox_name, pty: pty)
      end

      def backend_stop(sandbox_name)
        run_function(@functions.fetch(:stop), sandbox_name)
      end

      def backend_enter(sandbox_name)
        exec_function(@functions.fetch(:enter), sandbox_name)
      end

      def backend_is_running(sandbox_name)
        status = run_function(@functions.fetch(:is_running), sandbox_name, allow_failure: true)
        status.success?
      end

      def backend_get_ssh_port(sandbox_name)
        capture_function(@functions.fetch(:get_ssh_port), sandbox_name).strip
      end

      def backend_get_ip(sandbox_name)
        capture_function(@functions.fetch(:get_ip), sandbox_name).strip
      end

      def list
        function = @functions[:list]
        return unless function

        run_function(function)
      end

      def stop_all
        function = @functions[:stop_all]
        return unless function

        run_function(function)
      end

      private

      def exec_function(function, *args)
        @runner.exec(build_command(function, args))
      end

      def run_function(function, *args, pty: false, allow_failure: false)
        @runner.run(build_command(function, args), env: @env, pty: pty, allow_failure: allow_failure)
      end

      def capture_function(function, *args)
        @runner.capture(build_command(function, args), env: @env)
      end

      def build_command(function, args)
        script = +"set -euo pipefail\n"
        @source_files.each do |file|
          script << "source #{Shellwords.escape(file)}\n"
        end
        script << "SANDBOX_NAME=#{Shellwords.escape(args.first.to_s)}\n"
        script << "sandbox_name() { echo \"$SANDBOX_NAME\"; }\n"
        script << "#{function} #{args.map { |arg| Shellwords.escape(arg.to_s) }.join(' ')}\n"
        ['bash', '-lc', script]
      end
    end
  end
end
