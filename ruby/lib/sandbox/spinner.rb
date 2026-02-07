# frozen_string_literal: true

module Sandbox
  class Spinner
    FRAMES = %w[⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷].freeze

    def initialize(io: $stdout, interval: 0.1, tty: nil)
      @io = io
      @interval = interval
      @tty = tty.nil? ? io.tty? : tty
      @mutex = Mutex.new
      @running = false
      @task = nil
      @index = 0
    end

    def run(task)
      return run_without_tty(task) { yield } unless @tty

      @mutex.synchronize do
        @task = task
        @running = true
      end
      @io.print("#{frame} #{@task}\n")
      @io.flush
      thread = Thread.new { spin_loop }
      yield
    ensure
      stop(thread)
    end

    def update_task(task)
      @mutex.synchronize { @task = task }
    end

    private

    def run_without_tty(task)
      @io.puts("#{task}...")
      yield
    end

    def stop(thread)
      @mutex.synchronize { @running = false }
      thread&.join
    end

    def spin_loop
      while running?
        render
        sleep @interval
      end
    end

    def running?
      @mutex.synchronize { @running }
    end

    def frame
      @index = (@index + 1) % FRAMES.length
      FRAMES[@index]
    end

    def render
      task = @mutex.synchronize { @task }
      @io.print("\e[s\e[1A\e[2K#{frame} #{task}\e[u")
      @io.flush
    end
  end
end
