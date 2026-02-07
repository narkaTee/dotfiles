# frozen_string_literal: true

require 'shellwords'

module Sandbox
  class BashRunner
    def initialize(command_runner:, lib_root: nil)
      @command_runner = command_runner
      @lib_root = lib_root || detect_lib_root
    end

    def call(function_name, *args, env: {}, use_pty: false, capture: false)
      script = build_script(function_name)
      command = ['bash', '-lc', script, '--', *args]
      if capture
        @command_runner.capture(command, env: env)
      else
        @command_runner.run(command, env: env, use_pty: use_pty)
      end
    end

    def lib_root
      @lib_root
    end

    private

    def detect_lib_root
      env_path = ENV['SANDBOX_BASH_LIB_DIR']
      if env_path && File.exist?(File.join(env_path, 'common'))
        return env_path
      end

      home_path = File.join(Dir.home, '.config/lib/bash/sandbox')
      return home_path if File.exist?(File.join(home_path, 'common'))

      repo_path = File.expand_path('../../../bash/lib/sandbox', __dir__)
      return repo_path if File.exist?(File.join(repo_path, 'common'))

      raise Sandbox::Error, 'Unable to locate bash sandbox libraries'
    end

    def build_script(function_name)
      sources = sources_for(function_name).map { |file| source_line(file) }.join(\"\\n\")

      <<~BASH
        set -euo pipefail
        #{sandbox_helpers}
        #{sources}
        #{function_name} "$@"
      BASH
    end

    def sources_for(function_name)
      base = %w[
        common
        container-backend
        kvm-backend
        hcloud-backend
        proxy-backend
        proxy-cli
      ]

      if %w[ensure_know_agent bootstrap_ai].include?(function_name)
        base + ['ai-bootstrap']
      else
        base
      end
    end

    def source_line(file)
      path = File.join(@lib_root, file)
      "source #{Shellwords.shellescape(path)}"
    end

    def sandbox_helpers
      <<~BASH
        sandbox_name() {
          local name
          name="sandbox-$(basename "${PWD}")"
          echo "${name//[^a-zA-Z0-9_-]/_}"
        }

        backend_get_ssh_port() {
          local name="$1"
          case "${BACKEND:-}" in
            container) get_container_ssh_port "$name" ;;
            kvm) get_kvm_ssh_port "$name" ;;
            hcloud) get_hcloud_ssh_port "$name" ;;
          esac
        }

        backend_get_ip() {
          local name="$1"
          case "${BACKEND:-}" in
            container) get_container_ip "$name" ;;
            kvm) get_kvm_ip "$name" ;;
            hcloud) get_hcloud_ip "$name" ;;
          esac
        }
      BASH
    end
  end
end
