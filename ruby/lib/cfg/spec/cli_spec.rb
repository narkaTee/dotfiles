# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'
require 'stringio'

RSpec.describe Cfg::CLI do
  let(:test_repo_path) { Dir.mktmpdir }
  let(:profiles_dir) { File.join(test_repo_path, 'profiles') }
  let(:templates_dir) { File.join(test_repo_path, 'templates') }
  let(:mock_picker) { instance_double(Proc) }

  before do
    stub_const('Cfg::Storage::REPO_PATH', test_repo_path)
    stub_const('Cfg::Storage::PROFILES_DIR', profiles_dir)
    stub_const('Cfg::Storage::TEMPLATES_DIR', templates_dir)

    original_picker = Cfg::Selector.picker
    Cfg::Selector.picker = mock_picker
  end

  after do
    FileUtils.rm_rf(test_repo_path)
  end

  def capture_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    begin
      yield
      [$stdout.string, $stderr.string]
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end

  describe 'help' do
    it 'shows help with --help' do
      stdout, = capture_output { described_class.run(['--help']) }
      expect(stdout).to include('Usage: cfg')
      expect(stdout).to include('Commands:')
    end

    it 'shows help with no args' do
      stdout, = capture_output { described_class.run([]) }
      expect(stdout).to include('Usage: cfg')
    end
  end

  describe 'list' do
    context 'with no profiles' do
      it 'shows no profiles message' do
        stdout, = capture_output { described_class.run(['list']) }
        expect(stdout).to include('No profiles configured')
      end
    end

    context 'with profiles' do
      before do
        Cfg::Profiles.create_profile('test.profile', 'Test Profile', nil)
      end

      it 'lists profiles' do
        stdout, = capture_output { described_class.run(['list']) }
        expect(stdout).to include('test.profile')
        expect(stdout).to include('Test Profile')
        expect(stdout).not_to include('Key')
      end

      it 'works with ls alias' do
        stdout, = capture_output { described_class.run(['ls']) }
        expect(stdout).to include('test.profile')
      end
    end
  end

  describe 'add' do
    it 'creates a new profile' do
      stdout, = capture_output do
        described_class.run(['add', 'new.profile', '-d', 'New Profile'])
      end

      expect(stdout).to include('Created profile: new.profile')

      profile = Cfg::Profiles.get_profile('new.profile')
      expect(profile.description).to eq('New Profile')
    end

    it 'creates a profile with op_account' do
      stdout, = capture_output do
        described_class.run(['add', 'work.profile', '-d', 'Work Profile', '-a', 'myaccount'])
      end

      expect(stdout).to include('Created profile: work.profile')

      profile = Cfg::Profiles.get_profile('work.profile')
      expect(profile.description).to eq('Work Profile')
      expect(profile.op_account).to eq('myaccount')
    end
  end

  describe 'show' do
    before do
      Cfg::Profiles.create_profile('show.test', 'Show Test', 'myaccount')
    end

    it 'shows profile YAML' do
      stdout, = capture_output { described_class.run(['show', 'show.test']) }
      expect(stdout).to include('show.test')
      expect(stdout).to include('Show Test')
      expect(stdout).to include('myaccount')
    end
  end

  describe 'delete' do
    before do
      Cfg::Profiles.create_profile('delete.test', 'Delete Test', nil)
    end

    it 'deletes a profile' do
      stdout, = capture_output { described_class.run(['delete', 'delete.test']) }
      expect(stdout).to include('Deleted profile: delete.test')

      expect do
        Cfg::Profiles.get_profile('delete.test')
      end.to raise_error(Cfg::ProfileNotFoundError)
    end
  end

  describe 'sync' do
    it 'syncs with remote repository' do
      allow(Cfg::Git).to receive(:pull!)

      stdout, = capture_output { described_class.run(['sync']) }

      expect(Cfg::Git).to have_received(:pull!)
      expect(stdout).to include('Synced with remote')
    end
  end

  describe '--select' do
    before do
      Cfg::Profiles.create_profile('claude.work', 'Work', nil)
      Cfg::Profiles.create_profile('claude.personal', 'Personal', nil)
    end

    it 'returns exact match' do
      stdout, = capture_output { described_class.run(['--select', 'claude.work']) }
      expect(stdout.strip).to eq('claude.work')
    end

    it 'uses picker for multiple matches' do
      allow(mock_picker).to receive(:call).and_return('claude.personal - Personal')
      stdout, = capture_output { described_class.run(['--select', 'claude']) }
      expect(stdout.strip).to eq('claude.personal')
    end
  end

  describe '--has-profiles' do
    context 'with no profiles' do
      it 'exits 1 when no profiles exist' do
        expect do
          capture_output { described_class.run(['--has-profiles', 'claude']) }
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end
    end

    context 'with profiles' do
      before do
        Cfg::Profiles.create_profile('claude.work', 'Work', nil)
        Cfg::Profiles.create_profile('claude.personal', 'Personal', nil)
        Cfg::Profiles.create_profile('gemini.test', 'Gemini Test', nil)
      end

      it 'exits 0 when profiles exist for prefix' do
        expect do
          capture_output { described_class.run(['--has-profiles', 'claude']) }
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end

      it 'exits 0 when single profile matches prefix' do
        expect do
          capture_output { described_class.run(['--has-profiles', 'gemini']) }
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
      end

      it 'exits 1 when no profiles match prefix' do
        expect do
          capture_output { described_class.run(['--has-profiles', 'opencode']) }
        end.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
      end

      it 'requires prefix argument' do
        expect do
          capture_output { described_class.run(['--has-profiles']) }
        end.to raise_error(SystemExit)
      end
    end
  end

  describe 'import' do
    before do
      Cfg::Profiles.create_profile('import.test', 'Import Test', nil)
    end

    it 'imports a file as template' do
      temp_file = Tempfile.new(['import', '.txt'])
      temp_file.write("test content\n")
      temp_file.close

      stdout, = capture_output do
        described_class.run(['import', 'import.test', temp_file.path, '-t', '~/.config/test.txt'])
      end

      expect(stdout).to include('Imported')
      expect(stdout).to include('~/.config/test.txt')

      profile = Cfg::Profiles.get_profile('import.test')
      expect(profile.outputs.length).to eq(1)
      expect(profile.outputs.first.target).to eq('~/.config/test.txt')

      temp_file.unlink
    end
  end
end
