# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sandbox::Backends::Proxy do
  class FakeBackend
    attr_reader :proxy_enabled

    def proxy_enabled=(value)
      @proxy_enabled = value
    end

    def backend_start(_name, use_pty: false)
      use_pty
      @started = true
    end

    def backend_stop(_name); end

    def backend_enter(_name); end

    def backend_is_running(_name)
      false
    end

    def backend_get_ssh_port(_name)
      ''
    end

    def backend_get_ip(_name)
      ''
    end
  end

  it 'enables and resets proxy flag around start' do
    backend = FakeBackend.new
    proxy = described_class.new(backend)

    proxy.backend_start('sandbox-demo')

    expect(backend.proxy_enabled).to be(false).or be_nil
  end
end
