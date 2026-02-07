# frozen_string_literal: true

module Sandbox
  module Name
    module_function

    def sandbox_name(cwd)
      base = File.basename(cwd)
      sanitized = base.gsub(/[^a-zA-Z0-9_-]/, '_')
      "sandbox-#{sanitized}"
    end
  end
end
