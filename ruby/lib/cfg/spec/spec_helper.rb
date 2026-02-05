# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'
require 'openssl'

# Add lib to load path for testing
$LOAD_PATH.unshift(File.expand_path('../../', __dir__))

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end

# Shared helper for ephemeral SSH agent with Ed25519 key
module EphemeralAgent
  class << self
    attr_accessor :socket_path, :agent_pid, :public_key, :suffix

    def start
      @temp_dir = Dir.mktmpdir('cfg-test-agent')
      @key_path = File.join(@temp_dir, 'test_key')

      # Generate Ed25519 key without passphrase
      system('ssh-keygen', '-t', 'ed25519', '-f', @key_path, '-N', '', '-q')

      # Read public key and extract suffix (hash-based, filename-safe)
      @public_key = File.read("#{@key_path}.pub").strip
      @suffix = OpenSSL::Digest::SHA256.hexdigest(@public_key.split[1])[0, 6]

      # Start ssh-agent
      output, = Open3.capture2('ssh-agent', '-s')
      output.match(/SSH_AUTH_SOCK=([^;]+)/)
      @socket_path = Regexp.last_match(1)
      output.match(/SSH_AGENT_PID=(\d+)/)
      @agent_pid = Regexp.last_match(1).to_i

      # Add key to agent
      env = { 'SSH_AUTH_SOCK' => @socket_path }
      system(env, 'ssh-add', @key_path, %i[out err] => '/dev/null')
    end

    def stop
      Process.kill('TERM', @agent_pid) if @agent_pid
      FileUtils.rm_rf(@temp_dir) if @temp_dir
    rescue Errno::ESRCH
      # Agent already gone
    end

    def env
      { 'SSH_AUTH_SOCK' => @socket_path }
    end
  end
end

RSpec.shared_context 'with ephemeral agent' do
  before(:all) do
    EphemeralAgent.start
  end

  after(:all) do
    EphemeralAgent.stop
  end

  let(:agent_env) { EphemeralAgent.env }
  let(:public_key) { EphemeralAgent.public_key }
  let(:key_suffix) { EphemeralAgent.suffix }
end

RSpec.shared_context 'with temp cfg dir' do
  let(:temp_cfg_dir) { Dir.mktmpdir('cfg-test') }

  before do
    allow(Cfg::Storage).to receive(:cfg_dir).and_return(temp_cfg_dir)
    Cfg::Crypto.derived_keys.clear
  end

  after do
    FileUtils.rm_rf(temp_cfg_dir)
  end
end
