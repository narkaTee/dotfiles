# frozen_string_literal: true

require 'sandbox'
require 'sandbox/spec/spec_helper'

RSpec.describe Sandbox::BackendInterface do
  it 'raises when backend misses required methods' do
    backend = Struct.new(:backend_start).new(-> {})

    expect do
      described_class.validate!(backend)
    end.to raise_error(Sandbox::Error, /missing methods/)
  end
end
