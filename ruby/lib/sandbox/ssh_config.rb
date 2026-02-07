# frozen_string_literal: true

module Sandbox
  class SshConfig
    def initialize(bash_runner)
      @bash_runner = bash_runner
    end

    def alias_setup?(name)
      @bash_runner.call('is_ssh_alias_setup', name)
      true
    rescue Sandbox::CommandError
      false
    end

    def remove_alias(name)
      @bash_runner.call('remove_ssh_alias', name)
    end

    def remove_all_aliases
      @bash_runner.call('remove_all_ssh_aliases')
    end
  end
end
