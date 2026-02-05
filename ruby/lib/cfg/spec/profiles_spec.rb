# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Profiles do
  include_context 'with ephemeral agent'
  include_context 'with temp cfg dir'

  around do |example|
    original_sock = ENV['SSH_AUTH_SOCK']
    ENV['SSH_AUTH_SOCK'] = agent_env['SSH_AUTH_SOCK']
    example.run
  ensure
    ENV['SSH_AUTH_SOCK'] = original_sock
  end

  describe '.list_profiles' do
    context 'with no profiles' do
      it 'returns empty array' do
        profiles = described_class.list_profiles
        expect(profiles).to eq([])
      end
    end

    context 'with profiles' do
      before do
        described_class.create_profile('test.work', 'Test Work', 'work', key_suffix, public_key)
      end

      it 'returns array of Profile structs' do
        profiles = described_class.list_profiles
        expect(profiles.length).to eq(1)
        expect(profiles.first).to be_a(Cfg::Profile)
        expect(profiles.first.name).to eq('test.work')
      end
    end
  end

  describe '.create_profile' do
    it 'creates a new profile' do
      profile = described_class.create_profile('claude.work', 'Work Claude', 'work', key_suffix, public_key)

      expect(profile.name).to eq('claude.work')
      expect(profile.description).to eq('Work Claude')
      expect(profile.op_account).to eq('work')
      expect(profile.suffix).to eq(key_suffix)
      expect(profile.outputs).to eq([])
    end

    it 'adds suffix to index with comment stripped from public key' do
      described_class.create_profile('test.profile', 'Test', nil, key_suffix, public_key)

      index = Cfg::Storage.load_index
      expect(index[:index]).to have_key(key_suffix.to_sym)
      # Comment should be stripped - only type + key stored
      expected_key = public_key.split[0..1].join(' ')
      expect(index[:index][key_suffix.to_sym][:ssh_public_key]).to eq(expected_key)
    end

    it 'raises ProfileExistsError for duplicate name' do
      described_class.create_profile('dupe.test', 'Test', nil, key_suffix, public_key)

      expect do
        described_class.create_profile('dupe.test', 'Another', nil, key_suffix, public_key)
      end.to raise_error(Cfg::ProfileExistsError)
    end

    it 'raises InvalidProfileNameError for names with spaces' do
      expect do
        described_class.create_profile('claude - work', 'Test', nil, key_suffix, public_key)
      end.to raise_error(Cfg::InvalidProfileNameError)
    end

    it 'raises InvalidProfileNameError for names starting with special chars' do
      expect do
        described_class.create_profile('.hidden', 'Test', nil, key_suffix, public_key)
      end.to raise_error(Cfg::InvalidProfileNameError)
    end

    it 'allows valid names with dots, hyphens, underscores' do
      profile = described_class.create_profile('claude.work-v2_test', 'Test', nil, key_suffix, public_key)
      expect(profile.name).to eq('claude.work-v2_test')
    end
  end

  describe '.get_profile' do
    it 'returns profile by name' do
      described_class.create_profile('find.me', 'Find Me', 'personal', key_suffix, public_key)

      profile = described_class.get_profile('find.me')
      expect(profile.name).to eq('find.me')
      expect(profile.description).to eq('Find Me')
    end

    it 'raises ProfileNotFoundError for missing profile' do
      expect do
        described_class.get_profile('nonexistent')
      end.to raise_error(Cfg::ProfileNotFoundError)
    end
  end

  describe '.update_profile' do
    let!(:profile) do
      described_class.create_profile('update.me', 'Original', 'old', key_suffix, public_key)
    end

    it 'updates description' do
      updated = described_class.update_profile(profile, description: 'New Description')
      expect(updated.description).to eq('New Description')
    end

    it 'updates op_account' do
      updated = described_class.update_profile(profile, op_account: 'new_account')
      expect(updated.op_account).to eq('new_account')
    end
  end

  describe '.delete_profile' do
    it 'removes profile and its templates' do
      profile = described_class.create_profile('delete.me', 'Delete Me', nil, key_suffix, public_key)
      described_class.add_file_template(profile, '~/.config/test', 'content')

      described_class.delete_profile('delete.me')

      expect do
        described_class.get_profile('delete.me')
      end.to raise_error(Cfg::ProfileNotFoundError)
    end
  end

  describe 'template operations' do
    let!(:profile) do
      described_class.create_profile('templates.test', 'Test', nil, key_suffix, public_key)
    end

    describe '.add_file_template' do
      it 'adds a file template' do
        updated = described_class.add_file_template(profile, '~/.config/app.toml', 'key = "value"')

        expect(updated.outputs.length).to eq(1)
        output = updated.outputs.first
        expect(output.type).to eq('file')
        expect(output.target).to eq('~/.config/app.toml')
      end

      it 'replaces existing template with same target' do
        described_class.add_file_template(profile, '~/.config/app.toml', 'old content')
        updated = described_class.add_file_template(
          described_class.get_profile(profile.name),
          '~/.config/app.toml',
          'new content'
        )

        expect(updated.outputs.length).to eq(1)
        content = described_class.get_output_content(updated, updated.outputs.first)
        expect(content).to eq('new content')
      end

      it 'raises InvalidTargetPathError for relative paths' do
        expect do
          described_class.add_file_template(profile, 'config.toml', 'content')
        end.to raise_error(Cfg::InvalidTargetPathError)
      end

      it 'allows absolute paths starting with /' do
        updated = described_class.add_file_template(profile, '/etc/app/config.toml', 'content')
        expect(updated.outputs.first.target).to eq('/etc/app/config.toml')
      end
    end

    describe '.add_env_template' do
      it 'adds an env template' do
        updated = described_class.add_env_template(profile, "API_KEY=op://vault/item/key\n")

        expect(updated.outputs.length).to eq(1)
        output = updated.outputs.first
        expect(output.type).to eq('env')
        expect(output.target).to be_nil
      end

      it 'replaces existing env template' do
        described_class.add_env_template(profile, 'OLD=value')
        updated = described_class.add_env_template(
          described_class.get_profile(profile.name),
          'NEW=value'
        )

        expect(updated.outputs.count { |o| o.type == 'env' }).to eq(1)
        content = described_class.get_output_content(updated, updated.outputs.first)
        expect(content).to eq('NEW=value')
      end
    end

    describe '.get_output_content' do
      it 'returns decrypted content' do
        updated = described_class.add_file_template(profile, '~/.test', 'secret content')
        content = described_class.get_output_content(updated, updated.outputs.first)
        expect(content).to eq('secret content')
      end
    end

    describe '.update_output_content' do
      it 'updates template content' do
        updated = described_class.add_file_template(profile, '~/.test', 'original')
        output = updated.outputs.first

        final = described_class.update_output_content(updated, output, 'modified')
        content = described_class.get_output_content(final, final.outputs.first)
        expect(content).to eq('modified')
      end
    end

    describe '.delete_file_output' do
      it 'removes file output' do
        updated = described_class.add_file_template(profile, '~/.test', 'content')
        final = described_class.delete_file_output(updated, '~/.test')
        expect(final.outputs).to be_empty
      end
    end

    describe '.delete_env_output' do
      it 'removes env output' do
        updated = described_class.add_env_template(profile, 'KEY=value')
        final = described_class.delete_env_output(updated)
        expect(final.outputs).to be_empty
      end
    end

    describe '.import_file' do
      it 'imports file content as template' do
        temp_file = Tempfile.new('import-test')
        temp_file.write("imported content\n")
        temp_file.close

        begin
          updated = described_class.import_file(profile, temp_file.path, '~/.imported')
          content = described_class.get_output_content(updated, updated.outputs.first)
          expect(content).to eq("imported content\n")
        ensure
          temp_file.unlink
        end
      end
    end
  end
end
