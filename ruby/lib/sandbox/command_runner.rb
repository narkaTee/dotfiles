# frozen_string_literal: true

require 'open3'
require 'pty'

module Sandbox
  class CommandRunner
    def initialize(out: $stdout, err: $stderr)
      @out = out
      @err = err
    end

    def run(command, env: {}, chdir: nil, use_pty: false)
      if use_pty
        run_with_pty(command, env: env, chdir: chdir)
      else
        status = system(env, *command, chdir: chdir)
        raise CommandError.new("Command failed: #{command.join(' ')}", status: $?.exitstatus) unless status
        true
      end
    end

    def capture(command, env: {}, chdir: nil)
      stdout, stderr, status = Open3.capture3(env, *command, chdir: chdir)
      unless status.success?
        raise CommandError.new("Command failed: #{command.join(' ')}", status: status.exitstatus, stdout: stdout, stderr: stderr)
      end

      stdout
    end

    def exec(command, env: {}, chdir: nil)
      Kernel.exec(env, *command, chdir: chdir)
    end

    private

    def run_with_pty(command, env:, chdir: nil)
      pid = nil
      previous_int = trap('INT') { forward_signal(pid, 'INT') }
      previous_term = trap('TERM') { forward_signal(pid, 'TERM') }
      PTY.spawn(env, *command, chdir: chdir) do |reader, _writer, child_pid|
        pid = child_pid
        begin
          reader.each do |data|
            @out.print(data)
          end
        rescue Errno::EIO
          # PTY closed
        end
      end
      _, status = Process.wait2(pid)
      raise CommandError.new("Command failed: #{command.join(' ')}", status: status.exitstatus) unless status.success?
      true
    ensure
      trap('INT', previous_int) if previous_int
      trap('TERM', previous_term) if previous_term
    end

    def forward_signal(pid, signal)
      return unless pid

      Process.kill(signal, pid)
    rescue Errno::ESRCH
      nil
    end
  end
end
