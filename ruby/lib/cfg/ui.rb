# frozen_string_literal: true

require 'tempfile'
require 'io/console'

module Cfg
  module UI
    module_function

    # Prompt for text input from stdin
    def prompt_input(prompt)
      $stderr.print "#{prompt} "
      $stdin.gets&.chomp
    end

    # Run editor on content, return edited content or nil if unchanged/cancelled
    # extension: file extension for syntax highlighting (default: .txt)
    def run_editor(content, extension: '.txt')
      editor = ENV['VISUAL'] || ENV['EDITOR'] || 'vi'

      temp = Tempfile.new(['cfg-edit', extension])
      begin
        temp.write(content)
        temp.close

        # Run editor
        system(editor, temp.path)
        return nil unless $?.success?

        # Read back
        new_content = File.read(temp.path)
        return nil if new_content == content

        new_content
      ensure
        temp.unlink
      end
    end

    # Print formatted output
    def puts_table(rows, headers: nil)
      return if rows.empty?

      # Calculate column widths
      all_rows = headers ? [headers] + rows : rows
      widths = all_rows.first.length.times.map do |i|
        all_rows.map { |row| row[i].to_s.length }.max
      end

      format_row = ->(row) { row.each_with_index.map { |cell, i| cell.to_s.ljust(widths[i]) }.join('  ') }

      if headers
        puts format_row.call(headers)
        puts widths.map { |w| '-' * w }.join('  ')
      end

      rows.each { |row| puts format_row.call(row) }
    end

    # Show a spinner while executing a block
    # Returns the block's return value
    def with_spinner(message)
      return yield unless $stderr.tty?

      spinner_chars = ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷']
      spinner_thread = Thread.new do
        idx = 0
        loop do
          $stderr.print "\r#{spinner_chars[idx]} #{message}"
          $stderr.flush
          idx = (idx + 1) % spinner_chars.length
          sleep 0.1
        end
      end

      begin
        result = yield
        spinner_thread.kill
        $stderr.print "\r#{' ' * (message.length + 2)}\r"
        $stderr.flush
        result
      rescue StandardError => e
        spinner_thread.kill
        $stderr.print "\r#{' ' * (message.length + 2)}\r"
        $stderr.flush
        raise e
      end
    end
  end
end
