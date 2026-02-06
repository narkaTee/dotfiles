# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Cfg::Git do
  let(:repo_path) { '/tmp/test_cfg_repo' }
  let(:last_pull_file) { File.join(repo_path, '.last_pull') }

  before do
    stub_const('Cfg::Git::REPO_PATH', repo_path)
    stub_const('Cfg::Git::LAST_PULL_FILE', last_pull_file)
    allow(Open3).to receive(:capture3)

    # Unmock Git methods for this spec
    allow(Cfg::Git).to receive(:auto_sync!).and_call_original
    allow(Cfg::Git).to receive(:ensure_repo!).and_call_original
    allow(Cfg::Git).to receive(:commit!).and_call_original
    allow(Cfg::Git).to receive(:push!).and_call_original
  end

  describe '.ensure_repo!' do
    context 'when repo exists' do
      before do
        allow(Dir).to receive(:exist?).with(File.join(repo_path, '.git')).and_return(true)
      end

      it 'does nothing' do
        expect(Open3).not_to receive(:capture3)
        described_class.ensure_repo!
      end
    end

    context 'when repo does not exist' do
      before do
        allow(Dir).to receive(:exist?).with(File.join(repo_path, '.git')).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
      end

      it 'clones the repo and configures git author' do
        expect(Open3).to receive(:capture3)
          .with('git', 'clone', Cfg::Git::REPO_URL, repo_path)
          .and_return(['', '', double(success?: true)])
        expect(Open3).to receive(:capture3)
          .with('git', '-C', repo_path, 'github')
          .and_return(['', '', double(success?: true)])

        described_class.ensure_repo!
      end

      it 'raises error on clone failure' do
        expect(Open3).to receive(:capture3)
          .with('git', 'clone', Cfg::Git::REPO_URL, repo_path)
          .and_return(['', 'clone failed', double(success?: false)])

        expect { described_class.ensure_repo! }.to raise_error(Cfg::Error, /Failed to clone/)
      end

      it 'warns on git config failure but does not raise' do
        allow(Open3).to receive(:capture3)
          .with('git', 'clone', Cfg::Git::REPO_URL, repo_path)
          .and_return(['', '', double(success?: true)])
        allow(Open3).to receive(:capture3)
          .with('git', '-C', repo_path, 'github')
          .and_return(['', 'config failed', double(success?: false)])

        expect { described_class.ensure_repo! }.not_to raise_error
      end
    end
  end

  describe '.needs_pull?' do
    context 'when last_pull file does not exist' do
      before do
        allow(File).to receive(:exist?).with(last_pull_file).and_return(false)
      end

      it 'returns true' do
        expect(described_class.needs_pull?).to be true
      end
    end

    context 'when last_pull file is old' do
      before do
        allow(File).to receive(:exist?).with(last_pull_file).and_return(true)
        allow(File).to receive(:mtime).with(last_pull_file).and_return(Time.now - 3 * 60 * 60)
      end

      it 'returns true' do
        expect(described_class.needs_pull?).to be true
      end
    end

    context 'when last_pull file is recent' do
      before do
        allow(File).to receive(:exist?).with(last_pull_file).and_return(true)
        allow(File).to receive(:mtime).with(last_pull_file).and_return(Time.now - 60)
      end

      it 'returns false' do
        expect(described_class.needs_pull?).to be false
      end
    end
  end

  describe '.pull!' do
    before do
      allow(described_class).to receive(:ensure_repo!)
      allow(FileUtils).to receive(:touch)
    end

    it 'performs git pull with rebase' do
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'pull', '--rebase')
        .and_return(['pulled', '', double(success?: true)])

      described_class.pull!
    end

    it 'touches last_pull file on success' do
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      expect(FileUtils).to receive(:touch).with(last_pull_file)

      described_class.pull!
    end

    it 'raises error on failure' do
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'pull', '--rebase')
        .and_return(['', 'pull failed', double(success?: false)])

      expect { described_class.pull! }.to raise_error(Cfg::Error, /Failed to pull/)
    end
  end

  describe '.commit!' do
    before do
      allow(described_class).to receive(:ensure_repo!)
    end

    it 'adds all files and commits' do
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'add', '-A')
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'commit', '-m', 'test message')
        .and_return(['committed', '', double(success?: true)])

      described_class.commit!('test message')
    end

    it 'succeeds when nothing to commit' do
      allow(Open3).to receive(:capture3).with('git', '-C', repo_path, 'add', '-A')
      allow(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'commit', '-m', 'test message')
        .and_return(['', 'nothing to commit', double(success?: false)])

      expect { described_class.commit!('test message') }.not_to raise_error
    end

    it 'raises error on other failures' do
      allow(Open3).to receive(:capture3).with('git', '-C', repo_path, 'add', '-A')
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'commit', '-m', 'test message')
        .and_return(['', 'commit failed', double(success?: false)])

      expect { described_class.commit!('test message') }.to raise_error(Cfg::Error, /Failed to commit/)
    end
  end

  describe '.push!' do
    before do
      allow(described_class).to receive(:ensure_repo!)
    end

    it 'pushes to origin main' do
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'push', 'origin', 'main')
        .and_return(['pushed', '', double(success?: true)])

      described_class.push!
    end

    it 'warns on failure but does not raise' do
      expect(Open3).to receive(:capture3)
        .with('git', '-C', repo_path, 'push', 'origin', 'main')
        .and_return(['', 'push failed', double(success?: false)])

      expect { described_class.push! }.not_to raise_error
    end
  end

  describe '.auto_sync!' do
    context 'when pull is needed' do
      before do
        allow(described_class).to receive(:needs_pull?).and_return(true)
      end

      it 'performs pull' do
        expect(described_class).to receive(:pull!)
        described_class.auto_sync!
      end

      it 'warns on failure but does not raise' do
        allow(described_class).to receive(:pull!).and_raise(Cfg::Error, 'network error')
        expect { described_class.auto_sync! }.not_to raise_error
      end
    end

    context 'when pull is not needed' do
      before do
        allow(described_class).to receive(:needs_pull?).and_return(false)
      end

      it 'does nothing' do
        expect(described_class).not_to receive(:pull!)
        described_class.auto_sync!
      end
    end
  end
end
