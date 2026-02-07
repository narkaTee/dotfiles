# frozen_string_literal: true

require 'fileutils'

module Sandbox
  class SshAlias
    def initialize(config_dir: Paths.ssh_config_dir)
      @config_dir = config_dir
    end

    def setup(name, port, host: '127.0.0.1')
      return unless Dir.exist?(@config_dir)

      FileUtils.mkdir_p(@config_dir)
      path = alias_path(name)
      File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(<<~CONFIG)
          Host #{name}
              HostName #{host}
              Port #{port}
              User dev
              StrictHostKeyChecking no
              UserKnownHostsFile /dev/null
        CONFIG
      end
    end

    def remove(name)
      FileUtils.rm_f(alias_path(name))
    end

    def remove_all
      Dir.glob(File.join(@config_dir, 'alias-sandbox-*')).each do |path|
        FileUtils.rm_f(path)
      end
    end

    def configured?(name)
      File.exist?(alias_path(name))
    end

    private

    def alias_path(name)
      File.join(@config_dir, "alias-#{name}.conf")
    end
  end
end
