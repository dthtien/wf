require 'spec_helper'

describe Dwf::Utils, utils: true do
  describe '#symbolize_keys' do
    let(:expected) do
      {
        incoming: ['S'],
        outgoing: %w[A B],
        klass: 'H'
      }
    end

    let(:hash) do
      {
        'incoming' => ['S'],
        'outgoing' => %w[A B],
        'klass' => 'H'
      }
    end

    it { expect(described_class.symbolize_keys(hash)).to eq expected }
  end

  describe "#workflow_name?" do
    FirstWorkflow = Class.new(Dwf::Workflow)
    FirstJob = Class.new(Dwf::Item)

    it { expect(described_class.workflow_name?(FirstWorkflow.name)).to be_truthy }
    it { expect(described_class.workflow_name?(FirstJob.name)).to be_falsy }
  end
end
