# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sandbox::BackendSelector do
  let(:sandbox_name) { 'sandbox-demo' }

  def fake_backend(running)
    Class.new do
      define_method(:initialize) { |running| @running = running }
      define_method(:backend_is_running) { |_name| @running }
    end.new(running)
  end

  it 'returns explicit backend when provided' do
    selector = described_class.new(
      backends: { 'container' => fake_backend(false) },
      sandbox_name: sandbox_name
    )
    expect(selector.select_backend('kvm')).to eq('kvm')
  end

  it 'detects a running backend when no explicit backend is set' do
    selector = described_class.new(
      backends: {
        'container' => fake_backend(false),
        'kvm' => fake_backend(true)
      },
      sandbox_name: sandbox_name
    )
    expect(selector.select_backend(nil)).to eq('kvm')
  end

  it 'defaults to container when none are running' do
    selector = described_class.new(
      backends: { 'container' => fake_backend(false) },
      sandbox_name: sandbox_name
    )
    expect(selector.select_backend(nil)).to eq('container')
  end

  it 'raises when multiple backends are running' do
    selector = described_class.new(
      backends: {
        'container' => fake_backend(true),
        'kvm' => fake_backend(true)
      },
      sandbox_name: sandbox_name
    )
    expect { selector.detect_running_backend }.to raise_error(Sandbox::BackendConflictError)
  end
end
