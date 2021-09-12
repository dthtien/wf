# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'
class AItem < Dwf::Item; end

class BItem < Dwf::Item; end

class CItem < Dwf::Item; end

describe Dwf::Workflow, workflow: true do
  let(:workflow_id) { SecureRandom.uuid }
  let(:item_id) { SecureRandom.uuid }
  let(:client) do
    double(
      persist_workflow: nil,
      persist_job: nil,
      build_workflow_id: workflow_id,
      build_job_id: item_id,
      find_workflow: nil
    )
  end
  before do
    allow(Dwf::Client).to receive(:new).and_return client
  end

  describe '#create' do
    it do
      workflow = described_class.create
      expect(client).to have_received(:persist_workflow)
        .with(an_instance_of(described_class))
      expect(workflow.id).to eq workflow_id
      expect(workflow.persisted).to be_truthy
    end
  end

  describe '#persist!' do
    let(:workflow) { described_class.new }
    let(:job) do
      Dwf::Item.new(
        worflow_id: workflow_id,
        id: item_id
      )
    end
    before do
      workflow.jobs << job
      workflow.persist!
    end

    it do
      expect(client).to have_received(:persist_workflow)
        .with(an_instance_of(described_class))
      expect(client).to have_received(:persist_job).with(job)
      expect(workflow.id).to eq workflow_id
      expect(workflow.persisted).to be_truthy
    end
  end

  describe '#start' do
    let(:workflow) { described_class.new }
    let(:job) do
      Dwf::Item.new(
        worflow_id: workflow_id,
        id: item_id
      )
    end
    before do
      workflow.jobs << job
      workflow.persist!
    end

    it do
      expect(client).to have_received(:persist_workflow)
        .with(an_instance_of(described_class))
      expect(client).to have_received(:persist_job).with(job)
      expect(workflow.id).to eq workflow_id
      expect(workflow.persisted).to be_truthy
      expect(workflow.stopped).to be_falsy
    end
  end

  describe '#run' do
    let!(:workflow) { described_class.new }

    before do
      workflow.run AItem, after: BItem, before: CItem
    end

    it do
      expect(workflow.jobs).not_to be_empty
      expected = [
        {
          from: BItem.to_s,
          to: "AItem|#{item_id}"
        },
        {
          from: "AItem|#{item_id}",
          to: CItem.to_s
        }
      ]
      expect(workflow.dependencies).to match_array expected
    end
  end

  describe '#find_job' do
    let!(:workflow) { described_class.new }
    before do
      workflow.jobs = [
        AItem.new,
        BItem.new(id: item_id),
        CItem.new
      ]
    end

    it 'searches by klass' do
      job = workflow.find_job('AItem')
      expect(job).to be_kind_of AItem
    end

    it 'searches by name' do
      job = workflow.find_job("BItem|#{item_id}")
      expect(job).to be_kind_of BItem
    end
  end

  describe '#setup' do
    let!(:workflow) { described_class.new }
    before do
      workflow.run AItem
      workflow.run BItem, after: AItem
      workflow.run CItem, after: BItem

      workflow.send(:setup)
    end

    it do
      job_a = workflow.find_job('AItem')

      expect(job_a.incoming).to be_empty
      expect(job_a.outgoing).to eq ["BItem|#{item_id}"]

      job_b = workflow.find_job('BItem')

      expect(job_b.incoming).to eq ['AItem']
      expect(job_b.outgoing).to eq ["CItem|#{item_id}"]

      job_c = workflow.find_job('CItem')

      expect(job_c.incoming).to eq ['BItem']
      expect(job_c.outgoing).to be_empty
    end
  end

  describe '#callback_type' do
    let!(:workflow) { described_class.new }

    it {
      expect(workflow.callback_type).to eq described_class::BUILD_IN
      workflow.callback_type = described_class::SK_BATCH
      expect(workflow.callback_type).to eq described_class::SK_BATCH
    }
  end

  describe '#find' do
    before { Dwf::Workflow.find(workflow_id) }

    it { expect(client).to have_received(:find_workflow).with(workflow_id) }
  end
end
