# frozen_string_literal: true

require 'tempfile'

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
  end
end
