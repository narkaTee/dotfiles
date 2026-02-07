# frozen_string_literal: true

module Sandbox
  module Name
    module_function

    def from_dir(dir = Dir.pwd)
      base = File.basename(dir)
      sanitized = base.gsub(/[^a-zA-Z0-9_-]/, '_')
      "sandbox-#{sanitized}"
    end
  end
end
