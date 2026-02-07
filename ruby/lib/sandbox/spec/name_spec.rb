# frozen_string_literal: true

require 'sandbox'
require 'sandbox/spec/spec_helper'

RSpec.describe Sandbox::Name do
  it 'sanitizes directory names' do
    expect(described_class.from_dir('/tmp/hello world!')).to eq('sandbox-hello_world_')
  end

  it 'preserves alphanumeric, underscore, and dash' do
    expect(described_class.from_dir('/tmp/app-name_123')).to eq('sandbox-app-name_123')
  end
end
