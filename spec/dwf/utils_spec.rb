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
end
