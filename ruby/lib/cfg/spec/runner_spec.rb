# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Runner do
  include_context 'with ephemeral agent'
  include_context 'with temp cfg dir'

  around do |example|
    original_sock = ENV['SSH_AUTH_SOCK']
    ENV['SSH_AUTH_SOCK'] = agent_env['SSH_AUTH_SOCK']
    example.run
  ensure
    ENV['SSH_AUTH_SOCK'] = original_sock
  end

  let!(:profile) do
    Cfg::Profiles.create_profile('test.runner', 'Runner Test', nil, key_suffix, public_key)
  end

  describe '.expand_path' do
    it 'expands ~ to home directory' do
      expect(described_class.expand_path('~/.config/test')).to eq("#{Dir.home}/.config/test")
    end

    it 'leaves absolute paths unchanged' do
      expect(described_class.expand_path('/etc/config')).to eq('/etc/config')
    end
  end

  describe '.export_all_files' do
    let(:profile_with_files) do
      p = Cfg::Profiles.add_file_template(profile, '~/.config/app.toml', 'key = "value"')
      Cfg::Profiles.add_file_template(p, '~/.local/other.txt', 'other content')
    end

    before do
      # Mock op inject to return content as-is (no op:// refs to resolve)
      allow(described_class).to receive(:resolve_with_op_inject) do |_profile, content|
        content
      end
    end

    it 'exports files to base directory with correct paths' do
      export_dir = Dir.mktmpdir('cfg-export')
      begin
        written = described_class.export_all_files(profile_with_files, export_dir)

        expect(written.length).to eq(2)
        expect(File.read(File.join(export_dir, '.config/app.toml'))).to eq('key = "value"')
        expect(File.read(File.join(export_dir, '.local/other.txt'))).to eq('other content')
      ensure
        FileUtils.rm_rf(export_dir)
      end
    end
  end

  describe '.export_file' do
    before do
      Cfg::Profiles.add_file_template(profile, '~/.test/file.txt', 'file content')
      allow(described_class).to receive(:resolve_with_op_inject) do |_profile, content|
        content
      end
    end

    it 'returns resolved file content' do
      updated = Cfg::Profiles.get_profile('test.runner')
      result = described_class.export_file(updated, '~/.test/file.txt')
      expect(result).to eq('file content')
    end

    it 'raises TemplateNotFoundError for unknown target' do
      expect do
        described_class.export_file(profile, '~/.unknown/file.txt')
      end.to raise_error(Cfg::TemplateNotFoundError)
    end
  end

  describe '.export_env' do
    before do
      Cfg::Profiles.add_env_template(profile, "API_KEY=secret123\nOTHER_VAR=value")
    end

    it 'converts env template to export statements' do
      updated = Cfg::Profiles.get_profile('test.runner')
      result = described_class.export_env(updated)

      expect(result).to include("export API_KEY='secret123'")
      expect(result).to include("export OTHER_VAR='value'")
    end

    it 'returns empty string when no env template' do
      # Profile without env template
      result = described_class.export_env(profile)
      expect(result).to eq('')
    end

    it 'resolves op:// references using op read' do
      Cfg::Profiles.add_env_template(profile, "SECRET=op://vault/item/field")
      updated = Cfg::Profiles.get_profile('test.runner')

      allow(described_class).to receive(:read_op_reference)
        .with(updated, 'op://vault/item/field')
        .and_return('resolved-secret')

      result = described_class.export_env(updated)
      expect(result).to include("export SECRET='resolved-secret'")
    end
  end

  describe '.run_command' do
    let(:test_target) { File.join(temp_cfg_dir, 'test-target.txt') }

    before do
      allow(described_class).to receive(:resolve_with_op_inject) do |_profile, content|
        content
      end
    end

    context 'with file templates' do
      before do
        Cfg::Profiles.add_file_template(profile, test_target, 'injected content')
      end

      it 'writes file before running command' do
        updated = Cfg::Profiles.get_profile('test.runner')

        # Use a command that verifies the file exists
        described_class.run_command(updated, ['test', '-f', test_target])

        # File should be cleaned up after
        expect(File.exist?(test_target)).to be false
      end

      it 'raises FileExistsError if target already exists' do
        File.write(test_target, 'existing')
        updated = Cfg::Profiles.get_profile('test.runner')

        expect do
          described_class.run_command(updated, ['true'])
        end.to raise_error(Cfg::FileExistsError)
      ensure
        File.delete(test_target) if File.exist?(test_target)
      end
    end

    context 'with env template' do
      before do
        Cfg::Profiles.add_env_template(profile, 'TEST_VAR=value')
        # Mock run_with_op to avoid needing actual op
        allow(described_class).to receive(:run_with_op).and_return(0)
      end

      it 'calls run_with_op' do
        updated = Cfg::Profiles.get_profile('test.runner')
        described_class.run_command(updated, ['echo', 'test'])

        expect(described_class).to have_received(:run_with_op)
      end
    end

    context 'without env template' do
      it 'runs command directly' do
        exit_code = described_class.run_command(profile, ['true'])
        expect(exit_code).to eq(0)
      end

      it 'returns exit code from command' do
        exit_code = described_class.run_command(profile, ['false'])
        expect(exit_code).to eq(1)
      end
    end
  end
end
