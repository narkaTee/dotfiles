# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'open3'

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

  config.before do
    allow(Cfg::Git).to receive(:auto_sync!)
    allow(Cfg::Git).to receive(:ensure_repo!)
    allow(Cfg::Git).to receive(:commit!)
    allow(Cfg::Git).to receive(:push!)
  end
end

RSpec.shared_context 'with temp cfg dir' do
  let(:test_repo_path) { Dir.mktmpdir('cfg-test') }

  before do
    stub_const('Cfg::Git::REPO_PATH', test_repo_path)
    stub_const('Cfg::Storage::REPO_PATH', test_repo_path)
    stub_const('Cfg::Storage::PROFILES_DIR', File.join(test_repo_path, 'profiles'))
    stub_const('Cfg::Storage::TEMPLATES_DIR', File.join(test_repo_path, 'templates'))
  end

  after do
    FileUtils.rm_rf(test_repo_path)
  end
end
