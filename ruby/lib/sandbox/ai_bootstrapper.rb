# frozen_string_literal: true

require 'shellwords'

module Sandbox
  class AiBootstrapper
    def initialize(runner:, backend_name:, proxy: false)
      @runner = runner
      @backend_name = backend_name
      @proxy = proxy
    end

    def validate_agent!(agent)
      run_script("ensure_know_agent #{Shellwords.escape(agent)}")
    end

    def bootstrap!(sandbox_name, agent)
      script = <<~BASH
        ensure_know_agent #{Shellwords.escape(agent)}
        bootstrap_ai #{Shellwords.escape(sandbox_name)} #{Shellwords.escape(agent)}
      BASH
      run_script(script)
    end

    private

    def run_script(body)
      script = +"set -euo pipefail\n"
      script << "BACKEND=#{Shellwords.escape(@backend_name)}\n"
      script << "PROXY=#{Shellwords.escape(@proxy ? 'true' : 'false')}\n"
      script << "source #{Shellwords.escape(common_path)}\n"
      script << "source #{Shellwords.escape(proxy_path)}\n"
      script << "source #{Shellwords.escape(ai_bootstrap_path)}\n"
      script << "source #{Shellwords.escape(container_path)}\n"
      script << "source #{Shellwords.escape(kvm_path)}\n"
      script << "source #{Shellwords.escape(hcloud_path)}\n"
      script << <<~BASH
        backend_get_ssh_port() {
          local name="$1"
          case "$BACKEND" in
            container) get_container_ssh_port "$name" ;;
            kvm) get_kvm_ssh_port "$name" ;;
            hcloud) get_hcloud_ssh_port "$name" ;;
          esac
        }
      BASH
      script << body
      @runner.run(['bash', '-lc', script])
    end

    def common_path
      File.join(Dir.home, '.config/lib/bash/sandbox/common')
    end

    def proxy_path
      File.join(Dir.home, '.config/lib/bash/sandbox/proxy-backend')
    end

    def ai_bootstrap_path
      File.join(Dir.home, '.config/lib/bash/sandbox/ai-bootstrap')
    end

    def container_path
      File.join(Dir.home, '.config/lib/bash/sandbox/container-backend')
    end

    def kvm_path
      File.join(Dir.home, '.config/lib/bash/sandbox/kvm-backend')
    end

    def hcloud_path
      File.join(Dir.home, '.config/lib/bash/sandbox/hcloud-backend')
    end
  end
end
