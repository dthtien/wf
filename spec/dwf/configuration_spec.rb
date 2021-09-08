# frozen_string_literal: true

require 'spec_helper'

describe Dwf::Configuration, configuration: true do
  let(:configuration) { described_class.new }

  specify do
    expect(configuration.namespace).to eq described_class::NAMESPACE
    expect(configuration.redis_opts).to eq described_class::REDIS_OPTS
  end
end
