# frozen_string_literal: true

module Cfg
  class Error < StandardError; end
  class RepoUnavailableError < Error; end
  class ProfileNotFoundError < Error; end
  class TemplateNotFoundError < Error; end
  class ProfileExistsError < Error; end
  class FileExistsError < Error; end

  REPO_URL = "git@github.com:narkaTee/cfgs.git"
  REPO_PATH = File.join(Dir.home, ".local/share/cfg")
end

require_relative 'cfg/git'
require_relative 'cfg/storage'
require_relative 'cfg/profiles'
require_relative 'cfg/selector'
require_relative 'cfg/ui'
require_relative 'cfg/runner'
require_relative 'cfg/cli'
