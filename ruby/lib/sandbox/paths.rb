# frozen_string_literal: true

module Sandbox
  module Paths
    module_function

    def cache_base
      ENV.fetch('SANDBOX_CACHE_BASE', File.join(Dir.home, '.cache', 'sandbox'))
    end

    def ssh_config_dir
      ENV.fetch('SSH_CONFIG_DIR', File.join(Dir.home, '.ssh', 'config.d'))
    end

    def backend_state_dir(backend, name)
      File.join(cache_base, "#{backend}-vms", name)
    end
  end
end
