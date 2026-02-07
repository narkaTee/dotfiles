# frozen_string_literal: true

require 'shellwords'

module Sandbox
  class ProxyCli
    def initialize(runner:)
      @runner = runner
    end

    def run(args, sandbox_name)
      script = +"set -euo pipefail\n"
      script << "source #{Shellwords.escape(common_path)}\n"
      script << "source #{Shellwords.escape(proxy_backend_path)}\n"
      script << "source #{Shellwords.escape(proxy_cli_path)}\n"
      script << "SANDBOX_NAME=#{Shellwords.escape(sandbox_name)}\n"
      script << "sandbox_name() { echo \"$SANDBOX_NAME\"; }\n"
      script << "cmd_proxy #{args.map { |arg| Shellwords.escape(arg) }.join(' ')}\n"
      @runner.run(['bash', '-lc', script])
    end

    private

    def common_path
      File.join(Dir.home, '.config/lib/bash/sandbox/common')
    end

    def proxy_backend_path
      File.join(Dir.home, '.config/lib/bash/sandbox/proxy-backend')
    end

    def proxy_cli_path
      File.join(Dir.home, '.config/lib/bash/sandbox/proxy-cli')
    end
  end
end
