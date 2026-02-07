# frozen_string_literal: true

require 'open3'
require 'pty'

module Sandbox
  class CommandRunner
    def initialize(stdout: $stdout, stderr: $stderr)
      @stdout = stdout
      @stderr = stderr
    end

    def run(cmd, env: {}, pty: false, allow_failure: false)
      status = if pty
                 run_with_pty(cmd, env: env)
               else
                 run_with_open3(cmd, env: env)
               end
      return status if allow_failure || status.success?

      raise Error, "Command failed: #{cmd.join(' ')}"
    end

    def capture(cmd, env: {}, allow_failure: false)
      output, status = Open3.capture2e(env, *cmd)
      return output if allow_failure || status.success?

      raise Error, "Command failed: #{cmd.join(' ')}"
    end

    def exec(cmd, env: {})
      Kernel.exec(env, *cmd)
    end

    private

    def run_with_open3(cmd, env:)
      Open3.popen2e(env, *cmd) do |_stdin, stdout_err, wait|
        stdout_err.each { |chunk| @stdout.write(chunk) }
        @stdout.flush
        wait.value
      end
    end

    def run_with_pty(cmd, env:)
      status = nil
      PTY.spawn(env, *cmd) do |read, write, pid|
        write.close
        begin
          read.each do |chunk|
            @stdout.write(chunk)
            @stdout.flush
          end
        rescue Errno::EIO
          # PTY closed
        ensure
          Process.wait(pid)
          status = $?
        end
      end
      status
    end
  end
end
