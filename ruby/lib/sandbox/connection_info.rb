# frozen_string_literal: true

module Sandbox
  ConnectionInfo = Struct.new(:host, :port, :user, keyword_init: true) do
    def ssh_target
      user ? "#{user}@#{host}" : host
    end
  end
end
