# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Selector do
  include_context 'with ephemeral agent'
  include_context 'with temp cfg dir'

  # Mock picker for testing
  let(:mock_picker) { instance_double(Proc) }

  around do |example|
    original_sock = ENV['SSH_AUTH_SOCK']
    ENV['SSH_AUTH_SOCK'] = agent_env['SSH_AUTH_SOCK']

    # Save and restore picker
    original_picker = described_class.picker
    described_class.picker = mock_picker
    example.run
  ensure
    ENV['SSH_AUTH_SOCK'] = original_sock
    described_class.picker = original_picker
  end

  describe '.pick' do
    it 'returns nil for empty list' do
      result = described_class.pick([], 'prompt')
      expect(result).to be_nil
    end

    it 'returns single item without calling picker' do
      result = described_class.pick(['only one'], 'prompt')
      expect(result).to eq('only one')
    end

    it 'calls picker for multiple items' do
      allow(mock_picker).to receive(:call).with(%w[a b c], 'prompt').and_return('b')
      result = described_class.pick(%w[a b c], 'prompt')
      expect(result).to eq('b')
    end
  end

  describe '.select_profile' do
    before do
      Cfg::Profiles.create_profile('claude.work', 'Work Claude', nil, key_suffix, public_key)
      Cfg::Profiles.create_profile('claude.personal', 'Personal Claude', nil, key_suffix, public_key)
      Cfg::Profiles.create_profile('codex.work', 'Work Codex', nil, key_suffix, public_key)
    end

    it 'returns exact match without picker' do
      result = described_class.select_profile('claude.work')
      expect(result).to eq('claude.work')
    end

    it 'returns single prefix match without picker' do
      result = described_class.select_profile('codex')
      expect(result).to eq('codex.work')
    end

    it 'calls picker for multiple prefix matches' do
      allow(mock_picker).to receive(:call).and_return('claude.personal - Personal Claude')
      result = described_class.select_profile('claude')
      expect(result).to eq('claude.personal')
      expect(mock_picker).to have_received(:call).with(
        array_including('claude.work - Work Claude', 'claude.personal - Personal Claude'),
        'Select profile:'
      )
    end

    it 'returns nil when picker cancelled' do
      allow(mock_picker).to receive(:call).and_return(nil)
      result = described_class.select_profile('claude')
      expect(result).to be_nil
    end

    it 'returns nil for no matches' do
      result = described_class.select_profile('nonexistent')
      expect(result).to be_nil
    end

    it 'handles profile without description (fzf trims trailing space)' do
      Cfg::Profiles.create_profile('nodesc.test', nil, nil, key_suffix, public_key)
      # fzf may return trimmed string without trailing space
      allow(mock_picker).to receive(:call).and_return('nodesc.test -')
      result = described_class.select_profile('nodesc')
      expect(result).to eq('nodesc.test')
    end
  end

  describe '.select_ssh_key' do
    it 'returns single key suffix without picker' do
      keys = [[public_key, key_suffix]]
      result = described_class.select_ssh_key(keys)
      expect(result).to eq(key_suffix)
    end

    it 'returns nil for empty keys' do
      result = described_class.select_ssh_key([])
      expect(result).to be_nil
    end

    it 'calls picker for multiple keys showing suffix and comment' do
      keys = [
        ['ssh-ed25519 AAAA...abc123 work@laptop', 'abc123'],
        ['ssh-ed25519 BBBB...def456 personal@desktop', 'def456']
      ]
      allow(mock_picker).to receive(:call).and_return('def456 - personal@desktop')

      result = described_class.select_ssh_key(keys)
      expect(result).to eq('def456')
      expect(mock_picker).to have_received(:call).with(
        ['abc123 - work@laptop', 'def456 - personal@desktop'],
        'Select SSH key:'
      )
    end
  end

  describe '.select_file_target' do
    it 'returns single target without picker' do
      result = described_class.select_file_target(['~/.config/app.toml'])
      expect(result).to eq('~/.config/app.toml')
    end

    it 'returns nil for empty targets' do
      result = described_class.select_file_target([])
      expect(result).to be_nil
    end

    it 'calls picker for multiple targets' do
      targets = ['~/.config/a.toml', '~/.config/b.toml']
      allow(mock_picker).to receive(:call).and_return('~/.config/b.toml')

      result = described_class.select_file_target(targets)
      expect(result).to eq('~/.config/b.toml')
    end
  end
end
