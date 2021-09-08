# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'

describe Dwf::Client, client: true do
  let(:client) { described_class.new }
  let(:workflow_id) { SecureRandom.uuid }
  let(:id) { SecureRandom.uuid }
  let(:redis) { Redis.new }
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

    context 'find by item class name' do
      it {
        item = client.find_job(workflow_id, Dwf::Item.name)
        expect(item.workflow_id).to eq workflow_id
        expect(item.id).to eq id
        expect(item.name).to eq job.name
      }
    end

    context 'find by item name' do
      it {
        item = client.find_job(workflow_id, job.name)
        expect(item.workflow_id).to eq workflow_id
        expect(item.id).to eq id
        expect(item.name).to eq job.name
      }
    end
  end

  describe '#persist_job' do
    let!(:job) { Dwf::Item.new(workflow_id: workflow_id, id: id) }

    it do
      expect(redis.exists?("dwf.jobs.#{job.workflow_id}.#{job.klass}"))
        .to be_falsy

      client.persist_job(job)

      expect(redis.exists?("dwf.jobs.#{job.workflow_id}.#{job.klass}"))
        .to be_truthy
    end
  end

  describe '#persist_workflow' do
    let(:workflow) { Dwf::Workflow.new }

    it do
      expect(redis.exists?("dwf.workflows.#{workflow.id}")).to be_falsy
      client.persist_workflow(workflow)
      expect(redis.exists?("dwf.workflows.#{workflow.id}")).to be_truthy
    end
  end

  describe '#check_or_lock' do
    before do
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    context 'job is running' do
      let(:job_name) { 'ahihi' }

      before do
        allow(client).to receive(:set)
        redis.set("wf_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}", 'running')
        client.check_or_lock(workflow_id, job_name)
      end

      it { expect(client).not_to have_received(:set) }
    end

    context 'job is not running' do
      let(:job_name) { 'ahihi' }

      before do
        allow(redis).to receive(:set)
        client.check_or_lock(workflow_id, job_name)
      end

      it do
        expect(redis).to have_received(:set)
          .with("wf_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}", 'running')
      end
    end
  end

  describe '#release_lock' do
    before do
      allow(redis).to receive(:del)
      client.release_lock(workflow_id, 'ahihi')
    end

    it do
      expect(redis).to have_received(:del)
        .with("dwf_enqueue_outgoing_jobs_#{workflow_id}-ahihi")
    end
  end

  describe '#build_job_id' do
    before do
      allow(redis).to receive(:hexists)
      client.build_job_id(workflow_id, 'ahihi')
    end

    it { expect(redis).to have_received(:hexists) }
  end

  describe '#build_workflow_id' do
    before do
      allow(redis).to receive(:exists?)
      client.build_workflow_id
    end

    it { expect(redis).to have_received(:exists?) }
  end

  describe '#key_exists?' do
    before do
      allow(redis).to receive(:exists?)
      client.key_exists?('ahihi')
    end

    it { expect(redis).to have_received(:exists?).with('ahihi') }
  end

  describe '#set' do
    before do
      allow(redis).to receive(:set)
      client.set('ahihi', 'a')
    end

    it { expect(redis).to have_received(:set).with('ahihi', 'a') }
  end

  describe '#delete' do
    before do
      allow(redis).to receive(:del)
      client.delete('ahihi')
    end

    it { expect(redis).to have_received(:del).with('ahihi') }
  end
end