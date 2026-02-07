# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sandbox::Name do
  describe '.sandbox_name' do
    it 'prefixes and sanitizes the directory name' do
      name = described_class.sandbox_name('/tmp/my project!')
      expect(name).to eq('sandbox-my_project_')
    end

    it 'keeps allowed characters' do
      name = described_class.sandbox_name('/tmp/project-1_ok')
      expect(name).to eq('sandbox-project-1_ok')
    end
  end
end
