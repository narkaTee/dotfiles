# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'
require 'stringio'
require 'open3'

RSpec.describe 'cfg integration' do
  include_context 'with temp cfg dir'

  around do |example|
    original_picker = Cfg::Selector.picker
    Cfg::Selector.picker = method(:default_picker)

    example.run
  ensure
    Cfg::Selector.picker = original_picker
  end

  def default_picker(items, _prompt)
    items.first
  end

  def pick(answer)
    Cfg::Selector.picker = lambda do |items, _prompt|
      case answer
      when Integer then items[answer]
      when String then items.find { |i| i.include?(answer) }
      when Proc then answer.call(items)
      end
    end
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

  describe 'full workflow: add -> import -> show -> edit -> run -> delete' do
    it 'completes the full profile lifecycle' do
      stdout, = capture_output { Cfg::CLI.run(['add', 'test.workflow', '-d', 'Workflow Test']) }
      expect(stdout).to include('Created profile: test.workflow')

      temp_config = Tempfile.new(['config', '.toml'])
      temp_config.write("api_key = \"op://vault/item/key\"\n")
      temp_config.close

      stdout, = capture_output do
        Cfg::CLI.run(['import', 'test.workflow', temp_config.path, '-t', '~/.config/app.toml'])
      end
      expect(stdout).to include('Imported')

      stdout, = capture_output { Cfg::CLI.run(['show', 'test.workflow']) }
      expect(stdout).to include('test.workflow')
      expect(stdout).to include('~/.config/app.toml')

      stdout, = capture_output { Cfg::CLI.run(['show', 'test.workflow', 'file']) }
      expect(stdout).to include('api_key')
      expect(stdout).to include('op://vault/item/key')

      stdout, = capture_output { Cfg::CLI.run(['list']) }
      expect(stdout).to include('test.workflow')
      expect(stdout).to include('Workflow Test')

      stdout, = capture_output { Cfg::CLI.run(['delete', 'test.workflow']) }
      expect(stdout).to include('Deleted profile')

      stdout, = capture_output { Cfg::CLI.run(['list']) }
      expect(stdout).to include('No profiles configured')

      temp_config.unlink
    end
  end

  describe 'profile selection scenarios' do
    before do
      Cfg::Profiles.create_profile('claude.work', 'Work', nil)
      Cfg::Profiles.create_profile('claude.personal', 'Personal', nil)
      Cfg::Profiles.create_profile('codex.work', 'Codex', nil)
    end

    it 'direct selection with exact name' do
      stdout, = capture_output { Cfg::CLI.run(['--select', 'claude.work']) }
      expect(stdout.strip).to eq('claude.work')
    end

    it 'auto-selects single prefix match' do
      stdout, = capture_output { Cfg::CLI.run(['--select', 'codex']) }
      expect(stdout.strip).to eq('codex.work')
    end

    it 'uses picker for multiple prefix matches' do
      pick('personal')
      stdout, = capture_output { Cfg::CLI.run(['--select', 'claude']) }
      expect(stdout.strip).to eq('claude.personal')
    end
  end

  describe 'export functionality' do
    before do
      profile = Cfg::Profiles.create_profile('export.test', 'Export Test', nil)
      Cfg::Profiles.add_file_template(profile, '~/.config/a.txt', 'content A')
      profile = Cfg::Profiles.get_profile('export.test')
      Cfg::Profiles.add_file_template(profile, '~/.config/b.txt', 'content B')
      profile = Cfg::Profiles.get_profile('export.test')
      Cfg::Profiles.add_env_template(profile, "KEY1=value1\nKEY2=value2")

      allow(Cfg::Runner).to receive(:resolve_with_op_inject) { |_p, c| c }
    end

    it 'exports files to base directory' do
      export_dir = Dir.mktmpdir('cfg-export')
      begin
        stdout, = capture_output do
          Cfg::CLI.run(['export.test', '--export-file', '--base-dir', export_dir])
        end

        expect(stdout).to include('.config/a.txt')
        expect(stdout).to include('.config/b.txt')
        expect(File.read(File.join(export_dir, '.config/a.txt'))).to eq('content A')
        expect(File.read(File.join(export_dir, '.config/b.txt'))).to eq('content B')
      ensure
        FileUtils.rm_rf(export_dir)
      end
    end

    it 'exports single file to stdout' do
      stdout, = capture_output do
        Cfg::CLI.run(['export.test', '--export-file', '~/.config/a.txt'])
      end
      expect(stdout).to eq("content A\n")
    end

    it 'exports env as shell exports' do
      stdout, = capture_output { Cfg::CLI.run(['export.test', '--export-env']) }
      expect(stdout).to include("export KEY1='value1'")
      expect(stdout).to include("export KEY2='value2'")
    end
  end

  describe 'error handling' do
    it 'shows error for missing profile' do
      expect do
        capture_output { Cfg::CLI.run(['show', 'nonexistent']) }
      end.to raise_error(SystemExit)
    end

    it 'shows error for missing file template target' do
      Cfg::Profiles.create_profile('errors.test', 'Error Test', nil)
      allow(Cfg::Runner).to receive(:resolve_with_op_inject) { |_p, c| c }

      expect do
        capture_output do
          Cfg::CLI.run(['errors.test', '--export-file', '~/.nonexistent'])
        end
      end.to raise_error(SystemExit)
    end
  end

  describe 'env template workflow' do
    before do
      Cfg::Profiles.create_profile('env.test', 'Env Test', nil)
    end

    it 'shows env template after adding it' do
      profile = Cfg::Profiles.get_profile('env.test')
      Cfg::Profiles.add_env_template(profile, "API_KEY=op://vault/api/key\n")

      stdout, = capture_output { Cfg::CLI.run(['show', 'env.test', 'env']) }
      expect(stdout).to include('API_KEY')
      expect(stdout).to include('op://vault/api/key')
    end

    it 'deletes env template' do
      profile = Cfg::Profiles.get_profile('env.test')
      Cfg::Profiles.add_env_template(profile, 'KEY=value')

      stdout, = capture_output { Cfg::CLI.run(['delete', 'env.test', 'env']) }
      expect(stdout).to include('Deleted env template')

      profile = Cfg::Profiles.get_profile('env.test')
      expect(profile.outputs.count { |o| o.type == 'env' }).to eq(0)
    end
  end
end
