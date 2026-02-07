# frozen_string_literal: true

require 'sandbox'
require 'sandbox/spec/spec_helper'

RSpec.describe Sandbox::App do
  let(:runner) { Sandbox::CommandRunner.new(stdout: StringIO.new, stderr: StringIO.new) }
  let(:spinner) { Sandbox::Spinner.new(io: StringIO.new, tty: false) }
  let(:ssh_alias) { Sandbox::SshAlias.new(config_dir: Dir.mktmpdir) }

  def app_with(backends)
    described_class.new(
      backends: backends,
      runner: runner,
      spinner: spinner,
      ssh_alias: ssh_alias,
      proxy_cli: Sandbox::ProxyCli.new(runner: runner),
      stdout: StringIO.new,
      stderr: StringIO.new
    )
  end

  def backend_stub(name, running: false)
    Struct.new(:name) do
      define_method(:backend_is_running) { |_sandbox| running }
    end.new(name)
  end

  it 'uses explicit backend when provided' do
    app = app_with(
      'container' => backend_stub('container', running: true),
      'kvm' => backend_stub('kvm', running: true),
      'hcloud' => backend_stub('hcloud', running: false)
    )
    expect(app.send(:select_backend_name, backend: 'kvm')).to eq('kvm')
  end

  it 'detects running backend when not explicit' do
    app = app_with(
      'container' => backend_stub('container', running: false),
      'kvm' => backend_stub('kvm', running: true),
      'hcloud' => backend_stub('hcloud', running: false)
    )
    expect(app.send(:select_backend_name, {})).to eq('kvm')
  end

  it 'defaults to container when none running' do
    app = app_with(
      'container' => backend_stub('container', running: false),
      'kvm' => backend_stub('kvm', running: false),
      'hcloud' => backend_stub('hcloud', running: false)
    )
    expect(app.send(:select_backend_name, {})).to eq('container')
  end

  it 'raises when multiple backends are running' do
    app = app_with(
      'container' => backend_stub('container', running: true),
      'kvm' => backend_stub('kvm', running: true),
      'hcloud' => backend_stub('hcloud', running: false)
    )
    expect { app.send(:select_backend_name, {}) }.to raise_error(Sandbox::Error, /Multiple backends running/)
  end
end
