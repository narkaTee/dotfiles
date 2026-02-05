# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Storage do
  include_context 'with ephemeral agent'
  include_context 'with temp cfg dir'

  let(:encryption_key) { Cfg::Crypto.derive_key(public_key) }

  around do |example|
    original_sock = ENV['SSH_AUTH_SOCK']
    ENV['SSH_AUTH_SOCK'] = agent_env['SSH_AUTH_SOCK']
    example.run
  ensure
    ENV['SSH_AUTH_SOCK'] = original_sock
  end

  describe '.cfg_dir' do
    it 'returns temp directory in test context' do
      expect(described_class.cfg_dir).to eq(temp_cfg_dir)
    end
  end

  describe '.config_dir' do
    it 'returns path under cfg_dir/configs/<suffix>' do
      expect(described_class.config_dir('Az61gz')).to eq(File.join(temp_cfg_dir, 'configs', 'Az61gz'))
    end
  end

  describe 'index file operations' do
    it 'returns default index when file does not exist' do
      index = described_class.load_index
      expect(index[:encryption][:namespace]).to eq(Cfg::Crypto::NAMESPACE)
      expect(index[:index]).to eq({})
    end

    it 'saves and loads index correctly' do
      index = {
        encryption: { namespace: 'cfg-secrets-v1' },
        index: {
          'Az61gz' => {
            ssh_public_key: 'ssh-ed25519 AAAA...Az61gz',
            profiles_file: 'profiles-Az61gz.enc'
          }
        }
      }

      described_class.save_index(index)
      loaded = described_class.load_index

      expect(loaded[:encryption][:namespace]).to eq('cfg-secrets-v1')
      expect(loaded[:index][:'Az61gz'][:ssh_public_key]).to eq('ssh-ed25519 AAAA...Az61gz')
    end

    it 'creates cfg_dir if it does not exist' do
      FileUtils.rm_rf(temp_cfg_dir)
      described_class.save_index(described_class.default_index)
      expect(Dir.exist?(temp_cfg_dir)).to be true
    end
  end

  describe 'profiles file operations' do
    let(:profiles_data) do
      {
        'codex.work' => {
          description: 'Work Codex',
          op_account: 'work',
          outputs: [
            { template: 'b4c6d2e.enc', type: 'file', target: '~/.codex/config.toml' }
          ]
        }
      }
    end

    it 'returns empty hash when profiles file does not exist' do
      profiles = described_class.load_profiles(key_suffix, encryption_key)
      expect(profiles).to eq({})
    end

    it 'saves and loads profiles correctly' do
      described_class.save_profiles(key_suffix, profiles_data, encryption_key)
      loaded = described_class.load_profiles(key_suffix, encryption_key)

      expect(loaded[:'codex.work'][:description]).to eq('Work Codex')
      expect(loaded[:'codex.work'][:outputs].first[:template]).to eq('b4c6d2e.enc')
    end

    it 'creates encrypted file' do
      described_class.save_profiles(key_suffix, profiles_data, encryption_key)
      path = described_class.profiles_path(key_suffix)

      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).not_to include('codex.work')
    end
  end

  describe 'template file operations' do
    let(:template_content) { "ANTHROPIC_API_KEY=op://work/claude-api/credential\n" }
    let(:template_name) { 'test123.enc' }

    it 'saves and loads template correctly' do
      described_class.save_template(key_suffix, template_name, template_content, encryption_key)
      loaded = described_class.load_template(key_suffix, template_name, encryption_key)

      expect(loaded).to eq(template_content)
    end

    it 'creates config directory' do
      described_class.save_template(key_suffix, template_name, template_content, encryption_key)
      expect(Dir.exist?(described_class.config_dir(key_suffix))).to be true
    end

    it 'raises TemplateNotFoundError for missing template' do
      expect do
        described_class.load_template(key_suffix, 'nonexistent.enc', encryption_key)
      end.to raise_error(Cfg::TemplateNotFoundError)
    end

    it 'deletes template file' do
      described_class.save_template(key_suffix, template_name, template_content, encryption_key)
      described_class.delete_template(key_suffix, template_name)

      expect do
        described_class.load_template(key_suffix, template_name, encryption_key)
      end.to raise_error(Cfg::TemplateNotFoundError)
    end
  end

  describe '.generate_template_name' do
    it 'returns 7-char hex hash + .enc' do
      name = described_class.generate_template_name('some content')
      expect(name).to match(/\A[a-f0-9]{7}\.enc\z/)
    end

    it 'generates different names for different content' do
      name1 = described_class.generate_template_name('content 1')
      name2 = described_class.generate_template_name('content 2')
      expect(name1).not_to eq(name2)
    end

    it 'generates same name for same content' do
      name1 = described_class.generate_template_name('same content')
      name2 = described_class.generate_template_name('same content')
      expect(name1).to eq(name2)
    end
  end

  describe '.delete_suffix_data' do
    it 'removes profiles file and config directory' do
      described_class.save_profiles(key_suffix, { test: 'data' }, encryption_key)
      described_class.save_template(key_suffix, 'test.enc', 'content', encryption_key)

      expect(File.exist?(described_class.profiles_path(key_suffix))).to be true
      expect(Dir.exist?(described_class.config_dir(key_suffix))).to be true

      described_class.delete_suffix_data(key_suffix)

      expect(File.exist?(described_class.profiles_path(key_suffix))).to be false
      expect(Dir.exist?(described_class.config_dir(key_suffix))).to be false
    end
  end
end
