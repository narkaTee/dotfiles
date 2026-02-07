# frozen_string_literal: true

module Sandbox
  ConnectionInfo = Struct.new(:host, :port, :user, keyword_init: true)
end
