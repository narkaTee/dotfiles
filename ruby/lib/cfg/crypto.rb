# frozen_string_literal: true

require 'open3'
require 'openssl'
require 'base64'
require 'tempfile'

module Cfg
  module Crypto
    NAMESPACE = 'cfg-secrets-v1'

    @derived_keys = {}

    class << self
      attr_accessor :derived_keys
    end

    module_function

    # List Ed25519 keys from SSH agent
    # Returns array of [pubkey_line, suffix] pairs
    # Suffix is 6 hex chars from SHA256 hash of the key (filename-safe)
    def list_agent_keys
      output, status = Open3.capture2('ssh-add', '-L')
      return [] unless status.success?

      output.lines.filter_map do |line|
        line = line.strip
        next if line.empty?
        next unless line.start_with?('ssh-ed25519')

        parts = line.split
        next if parts.length < 2

        suffix = OpenSSL::Digest::SHA256.hexdigest(parts[1])[0, 6]
        [line, suffix]
      end
    end

    # Derive a 32-byte encryption key by signing NAMESPACE with SSH key
    # pubkey_line: full public key line (e.g., "ssh-ed25519 AAAA... comment")
    # Results are cached for the session
    def derive_key(pubkey_line)
      cached = Crypto.derived_keys[pubkey_line]
      return cached if cached

      # Write public key to temp file for ssh-keygen
      pubkey_file = Tempfile.new('cfg-pubkey')
      begin
        pubkey_file.write(pubkey_line)
        pubkey_file.close

        # Sign the namespace using ssh-keygen
        # This produces a deterministic signature for Ed25519 keys
        signature, stderr, status = Open3.capture3(
          'ssh-keygen', '-Y', 'sign',
          '-f', pubkey_file.path,
          '-n', NAMESPACE,
          stdin_data: NAMESPACE
        )

        raise CryptoError, "Failed to sign with SSH key: #{stderr}" unless status.success?

        # Hash the signature to get a 32-byte key
        key = OpenSSL::Digest::SHA256.digest(signature)
        Crypto.derived_keys[pubkey_line] = key
        key
      ensure
        pubkey_file.unlink
      end
    end

    # Encrypt data using AES-256-CBC
    # Returns base64-encoded IV + ciphertext
    def encrypt(plaintext, key)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv

      ciphertext = cipher.update(plaintext) + cipher.final
      Base64.strict_encode64(iv + ciphertext)
    end

    # Decrypt base64-encoded data
    def decrypt(encoded_data, key)
      data = Base64.strict_decode64(encoded_data)
      iv = data[0, 16]
      ciphertext = data[16..]

      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv

      result = cipher.update(ciphertext) + cipher.final
      result.force_encoding('UTF-8')
    rescue OpenSSL::Cipher::CipherError => e
      raise CryptoError, "Decryption failed: #{e.message}"
    end
  end
end
