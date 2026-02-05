# frozen_string_literal: true

require_relative 'spec_helper'
require 'cfg'
require 'stringio'

RSpec.describe Cfg::UI do
  describe '.prompt_input' do
    it 'reads input from stdin' do
      original_stdin = $stdin
      original_stderr = $stderr
      begin
        $stdin = StringIO.new("user input\n")
        $stderr = StringIO.new

        result = described_class.prompt_input('Enter value:')
        expect(result).to eq('user input')
        expect($stderr.string).to eq('Enter value: ')
      ensure
        $stdin = original_stdin
        $stderr = original_stderr
      end
    end

    it 'returns nil on EOF' do
      original_stdin = $stdin
      original_stderr = $stderr
      begin
        $stdin = StringIO.new('')
        $stderr = StringIO.new

        result = described_class.prompt_input('prompt')
        expect(result).to be_nil
      ensure
        $stdin = original_stdin
        $stderr = original_stderr
      end
    end
  end

  describe '.run_editor' do
    around do |example|
      original_editor = ENV['EDITOR']
      original_visual = ENV['VISUAL']
      ENV.delete('VISUAL')
      example.run
    ensure
      ENV['EDITOR'] = original_editor
      ENV['VISUAL'] = original_visual
    end

    it 'returns new content when edited' do
      # Create a helper script that modifies the file
      script = Tempfile.new(['editor', '.sh'])
      script.write("#!/bin/sh\necho modified > \"$1\"\n")
      script.close
      File.chmod(0o755, script.path)

      ENV['EDITOR'] = script.path
      result = described_class.run_editor('original content')
      expect(result).to eq("modified\n")

      script.unlink
    end

    it 'returns nil when content unchanged' do
      # Use true which does nothing
      ENV['EDITOR'] = 'true'

      result = described_class.run_editor('original content')
      expect(result).to be_nil
    end

    it 'returns nil when editor fails' do
      ENV['EDITOR'] = 'false'

      result = described_class.run_editor('content')
      expect(result).to be_nil
    end
  end

  describe '.puts_table' do
    it 'prints formatted table with headers' do
      original_stdout = $stdout
      begin
        $stdout = StringIO.new

        rows = [
          %w[a bb ccc],
          %w[dddd e f]
        ]
        described_class.puts_table(rows, headers: %w[Col1 Col2 Col3])

        output = $stdout.string
        expect(output).to include('Col1')
        expect(output).to include('Col2')
        expect(output).to include('----')
      ensure
        $stdout = original_stdout
      end
    end

    it 'prints table without headers' do
      original_stdout = $stdout
      begin
        $stdout = StringIO.new

        rows = [%w[a b], %w[c d]]
        described_class.puts_table(rows)

        output = $stdout.string
        expect(output).to include('a')
        expect(output).not_to include('---')
      ensure
        $stdout = original_stdout
      end
    end

    it 'handles empty rows' do
      original_stdout = $stdout
      begin
        $stdout = StringIO.new
        described_class.puts_table([])
        expect($stdout.string).to eq('')
      ensure
        $stdout = original_stdout
      end
    end
  end
end
