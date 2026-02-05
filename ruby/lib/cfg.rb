# frozen_string_literal: true

module Cfg
  class Error < StandardError; end
  class KeyNotFoundError < Error; end
  class ProfileNotFoundError < Error; end
  class TemplateNotFoundError < Error; end
  class ProfileExistsError < Error; end
  class FileExistsError < Error; end
  class CryptoError < Error; end
end

require_relative 'cfg/crypto'
require_relative 'cfg/storage'
require_relative 'cfg/profiles'
require_relative 'cfg/selector'
require_relative 'cfg/ui'
require_relative 'cfg/runner'
require_relative 'cfg/cli'
