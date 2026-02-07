# frozen_string_literal: true

require 'sandbox'
require 'sandbox/spec/spec_helper'

RSpec.describe Sandbox::Spinner do
  it 'prints a status line when stdout is not a TTY' do
    output = StringIO.new
    spinner = described_class.new(io: output, tty: false)

    spinner.run('Updating image') { output.write('done') }

    expect(output.string).to include('Updating image...')
    expect(output.string).to include('done')
  end

  it 'renders spinner frames when TTY is available' do
    output = StringIO.new
    spinner = described_class.new(io: output, tty: true, interval: 0.01)

    spinner.run('Starting container') { sleep(0.03) }

    expect(output.string).to include("\e[1A")
    expect(output.string).to match(/Starting container/)
  end
end
