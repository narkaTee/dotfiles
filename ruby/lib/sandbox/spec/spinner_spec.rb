# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

class FakeIO < StringIO
  def initialize(tty: false)
    super()
    @tty = tty
  end

  def tty?
    @tty
  end
end

RSpec.describe Sandbox::Spinner do
  it 'prints a status line when not a tty' do
    io = FakeIO.new(tty: false)
    spinner = described_class.new(io: io)

    spinner.with_task('Updating image') do
      io.print('done')
    end

    io.rewind
    output = io.read
    expect(output).to include("Updating image...\ndone")
  end

  it 'renders ANSI updates when tty' do
    io = FakeIO.new(tty: true)
    spinner = described_class.new(io: io)

    spinner.with_task('Starting') do
      sleep 0.15
    end

    io.rewind
    output = io.read
    expect(output).to include("\e[1A")
  end
end
