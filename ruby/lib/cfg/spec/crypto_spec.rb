# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Crypto do
  include_context 'with ephemeral agent'

  around do |example|
    # Use the ephemeral agent's SSH_AUTH_SOCK
    original_sock = ENV['SSH_AUTH_SOCK']
    ENV['SSH_AUTH_SOCK'] = agent_env['SSH_AUTH_SOCK']
    example.run
  ensure
    ENV['SSH_AUTH_SOCK'] = original_sock
  end

  describe '.list_agent_keys' do
    it 'finds the test Ed25519 key' do
      keys = described_class.list_agent_keys
      expect(keys).not_to be_empty
      expect(keys.length).to eq(1)

      pubkey_line, suffix = keys.first
      expect(pubkey_line).to start_with('ssh-ed25519')
      expect(suffix).to eq(key_suffix)
      expect(suffix.length).to eq(6)
    end

    it 'returns suffix as 6 hex chars from hash of public key' do
      keys = described_class.list_agent_keys
      pubkey_line, suffix = keys.first
      key_part = pubkey_line.split[1]
      expected = OpenSSL::Digest::SHA256.hexdigest(key_part)[0, 6]
      expect(suffix).to eq(expected)
    end
  end

  describe '.derive_key' do
    it 'produces a 32-byte key' do
      key = described_class.derive_key(public_key)
      expect(key.bytesize).to eq(32)
    end

    it 'produces consistent output for same input' do
      key1 = described_class.derive_key(public_key)
      key2 = described_class.derive_key(public_key)
      expect(key1).to eq(key2)
    end
  end

  describe '.encrypt and .decrypt' do
    let(:encryption_key) { described_class.derive_key(public_key) }
    let(:plaintext) { 'Hello, World! This is sensitive data.' }

    it 'round-trips correctly' do
      encrypted = described_class.encrypt(plaintext, encryption_key)
      decrypted = described_class.decrypt(encrypted, encryption_key)
      expect(decrypted).to eq(plaintext)
    end

    it 'produces different ciphertext each time (random IV)' do
      encrypted1 = described_class.encrypt(plaintext, encryption_key)
      encrypted2 = described_class.encrypt(plaintext, encryption_key)
      expect(encrypted1).not_to eq(encrypted2)
    end

    it 'produces base64-encoded output' do
      encrypted = described_class.encrypt(plaintext, encryption_key)
      expect { Base64.strict_decode64(encrypted) }.not_to raise_error
    end

    it 'fails with wrong key' do
      encrypted = described_class.encrypt(plaintext, encryption_key)
      wrong_key = OpenSSL::Random.random_bytes(32)
      expect { described_class.decrypt(encrypted, wrong_key) }.to raise_error(Cfg::CryptoError)
    end

    it 'handles empty string' do
      encrypted = described_class.encrypt('', encryption_key)
      decrypted = described_class.decrypt(encrypted, encryption_key)
      expect(decrypted).to eq('')
    end

    it 'handles unicode content' do
      unicode_text = "日本語テスト 🔐 émojis"
      encrypted = described_class.encrypt(unicode_text, encryption_key)
      decrypted = described_class.decrypt(encrypted, encryption_key)
      expect(decrypted).to eq(unicode_text)
    end

    it 'handles large content' do
      large_text = 'x' * 100_000
      encrypted = described_class.encrypt(large_text, encryption_key)
      decrypted = described_class.decrypt(encrypted, encryption_key)
      expect(decrypted).to eq(large_text)
    end
  end
end
