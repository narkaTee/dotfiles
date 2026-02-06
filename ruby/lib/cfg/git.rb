# frozen_string_literal: true

require 'fileutils'
require 'open3'

module Cfg
  module Git
    REPO_URL = "git@github.com:narkaTee/cfgs.git"
    REPO_PATH = File.join(Dir.home, ".local/share/cfg")
    LAST_PULL_FILE = File.join(REPO_PATH, ".last_pull")
    AUTO_PULL_INTERVAL = 2 * 60 * 60

    module_function

    def ensure_repo!
      return if Dir.exist?(File.join(REPO_PATH, '.git'))

      FileUtils.mkdir_p(File.dirname(REPO_PATH))
      stdout, stderr, status = Open3.capture3('git', 'clone', REPO_URL, REPO_PATH)
      raise Error, "Failed to clone repo: #{stderr}" unless status.success?

      _, stderr_config, status_config = Open3.capture3('git', '-C', REPO_PATH, 'github')
      warn "Warning: Failed to configure git author: #{stderr_config}" unless status_config.success?

      stdout
    end

    def needs_pull?
      return true unless File.exist?(LAST_PULL_FILE)

      last_pull = File.mtime(LAST_PULL_FILE)
      Time.now - last_pull > AUTO_PULL_INTERVAL
    end

    def pull!
      ensure_repo!
      stdout, stderr, status = Open3.capture3('git', '-C', REPO_PATH, 'pull', '--rebase')
      unless status.success?
        raise Error, "Failed to pull: #{stderr}"
      end

      FileUtils.touch(LAST_PULL_FILE)
      stdout
    end

    def commit!(message)
      ensure_repo!
      Open3.capture3('git', '-C', REPO_PATH, 'add', '-A')
      stdout, stderr, status = Open3.capture3('git', '-C', REPO_PATH, 'commit', '-m', message)

      return stdout if status.success?
      return stdout if stderr.include?('nothing to commit')

      raise Error, "Failed to commit: #{stderr}"
    end

    def push!
      ensure_repo!
      stdout, stderr, status = Open3.capture3('git', '-C', REPO_PATH, 'push', 'origin', 'main')
      warn "Warning: Failed to push: #{stderr}" unless status.success?
      stdout
    end

    def auto_sync!
      return unless needs_pull?

      pull!
    rescue Error => e
      warn "Warning: Auto-sync failed: #{e.message}"
    end
  end
end
