# frozen_string_literal: true

module Sandbox
  class Spinner
    FRAMES = %w[⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷].freeze
    INTERVAL = 0.1

    def initialize(io: $stdout)
      @io = io
      @label = nil
      @active = false
      @thread = nil
      @index = 0
    end

    def tty?
      @io.respond_to?(:tty?) && @io.tty?
    end

    def with_task(label)
      if tty?
        start(label)
        yield
      else
        @io.puts("#{label}...")
        yield
      end
    ensure
      stop if tty?
    end

    def update(label)
      @label = label
    end

    private

    def start(label)
      @label = label
      @active = true
      render_line
      @io.print("\n")
      @io.flush
      @thread = Thread.new { spin }
    end

    def stop
      @active = false
      @thread&.join
      clear_line
    end

    def spin
      while @active
        sleep INTERVAL
        @index = (@index + 1) % FRAMES.length
        render_line
      end
    end

    def render_line
      @io.print("\e7\e[1A\e[2K#{FRAMES[@index]} #{@label}\e8")
      @io.flush
    end

    def clear_line
      @io.print("\e7\e[1A\e[2K#{@label}\e8")
      @io.flush
    end
  end
end
