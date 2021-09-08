# frozen_string_literal: true

require 'spec_helper'

describe Dwf::Configuration, configuration: true do
  let(:configuration) { described_class.new }

  specify do
    expect(configuration.concurrency).to eq described_class::CONCURRENCY
    expect(configuration.namespace).to eq described_class::NAMESPACE
    expect(configuration.redis_url).to eq described_class::REDIS_URL
    expect(configuration.ttl).to eq described_class::TTL
  end
end
