# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'
require 'sidekiq/testing'

describe Dwf::Worker, client: true do
  let(:workflow_id) { SecureRandom.uuid }
  let(:id) { SecureRandom.uuid }
  let(:redis) { Redis.new }
  let(:worker) { described_class.perform_async(workflow_id, job.name) }
  before do
    redis_instance = MockRedis.new
    allow(Redis).to receive(:new).and_return redis_instance
  end

  describe '#find_job' do
    let!(:job) do
      j = Dwf::Item.new(workflow_id: workflow_id, id: id)
      j.persist!
      j
    end

    before do
      worker
      Sidekiq::Worker.drain_all
      job.reload
    end

    it { expect(job.finished?).to be_truthy }
  end
end
