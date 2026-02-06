# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'

RSpec.describe Cfg::Storage do
  let(:test_repo_path) { Dir.mktmpdir }
  let(:profiles_dir) { File.join(test_repo_path, 'profiles') }
  let(:templates_dir) { File.join(test_repo_path, 'templates') }

  before do
    stub_const('Cfg::Storage::REPO_PATH', test_repo_path)
    stub_const('Cfg::Storage::PROFILES_DIR', profiles_dir)
    stub_const('Cfg::Storage::TEMPLATES_DIR', templates_dir)
  end

  after do
    FileUtils.rm_rf(test_repo_path)
  end

  describe '.list_profile_names' do
    it 'returns empty array when profiles dir does not exist' do
      expect(described_class.list_profile_names).to eq([])
    end

    it 'returns profile names without .yaml extension' do
      FileUtils.mkdir_p(profiles_dir)
      File.write(File.join(profiles_dir, 'test1.yaml'), '')
      File.write(File.join(profiles_dir, 'test2.yaml'), '')

      names = described_class.list_profile_names
      expect(names).to contain_exactly('test1', 'test2')
    end
  end

  describe '.load_profile and .save_profile' do
    let(:profile_data) do
      {
        description: 'Test Profile',
        op_account: 'work',
        outputs: [
          { template: 'abc123.json', type: 'file', target: '~/.config/test.json' }
        ]
      }
    end

    it 'saves and loads profile correctly' do
      described_class.save_profile('test', profile_data)
      loaded = described_class.load_profile('test')

      expect(loaded[:description]).to eq('Test Profile')
      expect(loaded[:op_account]).to eq('work')
      expect(loaded[:outputs].first[:template]).to eq('abc123.json')
    end

    it 'creates profiles directory if needed' do
      described_class.save_profile('test', profile_data)
      expect(Dir.exist?(profiles_dir)).to be true
    end

    it 'raises ProfileNotFoundError for missing profile' do
      expect do
        described_class.load_profile('nonexistent')
      end.to raise_error(Cfg::ProfileNotFoundError)
    end

    it 'stores data as plaintext YAML' do
      described_class.save_profile('test', profile_data)
      path = File.join(profiles_dir, 'test.yaml')
      content = File.read(path)

      expect(content).to include('Test Profile')
      expect(content).to include('work')
    end
  end

  describe '.delete_profile' do
    it 'deletes profile file' do
      described_class.save_profile('test', { description: 'test' })
      expect(File.exist?(File.join(profiles_dir, 'test.yaml'))).to be true

      described_class.delete_profile('test')
      expect(File.exist?(File.join(profiles_dir, 'test.yaml'))).to be false
    end

    it 'does not error if profile does not exist' do
      expect { described_class.delete_profile('nonexistent') }.not_to raise_error
    end
  end

  describe '.load_template and .save_template' do
    let(:template_content) { "ANTHROPIC_API_KEY=op://work/claude-api/credential\n" }

    it 'saves and loads template correctly' do
      described_class.save_template('abc123.env', template_content)
      loaded = described_class.load_template('abc123.env')

      expect(loaded).to eq(template_content)
    end

    it 'creates templates directory if needed' do
      described_class.save_template('abc123.env', template_content)
      expect(Dir.exist?(templates_dir)).to be true
    end

    it 'raises TemplateNotFoundError for missing template' do
      expect do
        described_class.load_template('nonexistent.env')
      end.to raise_error(Cfg::TemplateNotFoundError)
    end

    it 'stores content as plaintext' do
      described_class.save_template('abc123.env', template_content)
      path = File.join(templates_dir, 'abc123.env')
      content = File.read(path)

      expect(content).to eq(template_content)
    end
  end

  describe '.delete_template' do
    it 'deletes template file' do
      described_class.save_template('test.env', 'content')
      expect(File.exist?(File.join(templates_dir, 'test.env'))).to be true

      described_class.delete_template('test.env')
      expect(File.exist?(File.join(templates_dir, 'test.env'))).to be false
    end

    it 'does not error if template does not exist' do
      expect { described_class.delete_template('nonexistent.env') }.not_to raise_error
    end
  end

  describe '.generate_template_name' do
    it 'returns 7-char hex hash + extension' do
      name = described_class.generate_template_name('some content', 'json')
      expect(name).to match(/\A[a-f0-9]{7}\.json\z/)
    end

    it 'supports different extensions' do
      name_json = described_class.generate_template_name('content', 'json')
      name_env = described_class.generate_template_name('content', 'env')

      expect(name_json).to end_with('.json')
      expect(name_env).to end_with('.env')
    end

    it 'generates different names for different content' do
      name1 = described_class.generate_template_name('content 1', 'json')
      name2 = described_class.generate_template_name('content 2', 'json')
      expect(name1).not_to eq(name2)
    end

    it 'generates same name for same content and extension' do
      name1 = described_class.generate_template_name('same content', 'json')
      name2 = described_class.generate_template_name('same content', 'json')
      expect(name1).to eq(name2)
    end
  end
end
