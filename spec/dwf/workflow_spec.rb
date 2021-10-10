# frozen_string_literal: true

require 'spec_helper'
require 'mock_redis'
AItem = Class.new(Dwf::Item)
BItem = Class.new(Dwf::Item)
CItem = Class.new(Dwf::Item)
SWorkflow = Class.new(Dwf::Workflow)

describe Dwf::Workflow, workflow: true do
  let(:workflow_id) { SecureRandom.uuid }
  let(:item_id) { SecureRandom.uuid }
  let(:item) { nil }
  let(:client) do
    double(
      persist_workflow: nil,
      persist_job: nil,
      build_workflow_id: workflow_id,
      build_job_id: item_id,
      find_workflow: nil,
      find_node: item,
      check_or_lock: nil,
      release_lock: nil
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

  describe '#find' do
    before { Dwf::Workflow.find(workflow_id) }

    it { expect(client).to have_received(:find_workflow).with(workflow_id) }
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
      workflow.run SWorkflow, after: AItem
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
        },
        {
          from: AItem.to_s,
          to: "SWorkflow|#{workflow_id}"
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
      workflow.run SWorkflow, after: BItem
      workflow.run CItem, after: SWorkflow

      workflow.send(:setup)
    end

    it do
      job_a = workflow.find_job("AItem")

      expect(job_a.incoming).to be_empty
      expect(job_a.outgoing).to eq ["BItem|#{item_id}"]

      job_b = workflow.find_job('BItem')

      expect(job_b.incoming).to eq ["AItem|#{item_id}"]
      expect(job_b.outgoing).to eq ["SWorkflow|#{workflow_id}"]

      job_c = workflow.find_job('CItem')

      expect(job_c.incoming).to eq ["SWorkflow|#{workflow_id}"]
      expect(job_c.outgoing).to be_empty
    end
  end

  describe '#callback_type' do
    let!(:workflow) { described_class.new }

    it do
      expect(workflow.callback_type).to eq described_class::BUILD_IN
      workflow.callback_type = described_class::SK_BATCH
      expect(workflow.callback_type).to eq described_class::SK_BATCH
    end
  end

  describe '#reload' do
    let!(:workflow) do
      flow = described_class.new
      flow.id = workflow_id
      flow
    end

    before do
      allow(client).to receive(:find_workflow).and_return workflow
      workflow.reload
    end

    it { expect(client).to have_received(:find_workflow).with(workflow_id) }
  end

  describe '#parents_succeeded?' do
    let(:incoming) { ["A|#{SecureRandom.uuid}"] }
    let!(:workflow) do
      flow = described_class.new
      flow.parent_id = SecureRandom.uuid
      flow.incoming = incoming
      flow
    end
    let(:item) do
      Dwf::Item.new(
        workflow_id: SecureRandom.uuid,
        id: SecureRandom.uuid,
        finished_at: finished_at
      )
    end

    context 'parent jobs already finished' do
      let(:finished_at) { Time.now.to_i }

      it do
        expect(workflow.parents_succeeded?).to be_truthy
        expect(client).to have_received(:find_node)
          .with(incoming.first, workflow.parent_id)
      end
    end

    context 'parent jobs havent finished yet' do
      let(:finished_at) { nil }

      it do
        expect(workflow.parents_succeeded?).to be_falsy
        expect(client)
          .to have_received(:find_node)
          .with(incoming.first, workflow.parent_id)
      end
    end
  end

  describe '#sub_workflow?' do
    let!(:workflow) { described_class.new }
    let!(:sub_workflow) do
      flow = described_class.new
      flow.parent_id = workflow.id
      flow
    end

    specify do
      expect(workflow.sub_workflow?).to be_falsy
      expect(sub_workflow.sub_workflow?).to be_truthy
    end
  end

  describe '#payloads' do
    let!(:item) do
      Dwf::Item.new(
        workflow_id: SecureRandom.uuid,
        id: SecureRandom.uuid,
        output_payload: 1
      )
    end
    let(:workflow) { described_class.new }

    context 'when workflow is main flow' do
      it { expect(workflow.payloads).to be_nil }
    end

    context 'when workflow is sub flow' do
      before do
        workflow.incoming = incoming
        workflow.parent_id = SecureRandom.uuid
      end

      context 'when incoming blank' do
        let(:incoming) { [] }
        it { expect(workflow.payloads).to be_nil }
      end

      context 'when incoming present' do
        let(:incoming) { ["Dwf::Item|#{SecureRandom.uuid}", "Dwf::Workflow|#{workflow_id}"] }
        it do
          expected_payload = [
            {
              class: item.class.name,
              id: item.name,
              output: 1
            }
          ]
          expect(workflow.payloads).to eq expected_payload
          expect(client).to have_received(:find_node).with(incoming.first, workflow.parent_id)
        end
      end
    end
  end

  describe '#left?' do
    let(:workflow) { described_class.new }
    before { workflow.outgoing = outgoing }

    context 'when item has outgoing item' do
      let(:outgoing) { ["Dwf::Item|#{SecureRandom.uuid}"] }
      it { expect(workflow.leaf?).to be_falsy }
    end

    context 'when item does not have outgoing item' do
      let(:outgoing) { [] }
      it { expect(workflow.leaf?).to be_truthy }
    end
  end

  describe '#leaf_nodes' do
    let!(:workflow) { described_class.new }
    before do
      workflow.run AItem
      workflow.run BItem, after: AItem
      workflow.run SWorkflow, after: BItem
      workflow.run CItem, after: SWorkflow

      workflow.send(:setup)
    end

    specify do
      expect(workflow.leaf_nodes.count).to eq 1
      expect(workflow.leaf_nodes.first).to be_kind_of CItem
    end
  end

  describe '#output_payloads' do
    let!(:workflow) { described_class.new }
    before do
      allow_any_instance_of(CItem).to receive(:output_payload).and_return 1
      workflow.run AItem
      workflow.run BItem, after: AItem
      workflow.run SWorkflow, after: BItem
      workflow.run CItem, after: SWorkflow

      workflow.send(:setup)
    end

    it { expect(workflow.output_payload).to eq [1] }
  end

  describe '#callback_type=' do
    let!(:workflow) { described_class.new }
    before do
      workflow.run AItem
      workflow.run BItem, after: AItem

      workflow.send(:setup)
      workflow.callback_type = described_class::SK_BATCH
    end

    specify do
      expect(workflow.callback_type).to eq described_class::SK_BATCH
      job_callback_types = workflow.jobs.map(&:callback_type).uniq
      expect(job_callback_types).to eq [described_class::SK_BATCH]
    end
  end

  describe '#enqueue_outgoing_jobs' do
    let(:outgoing) { ["A|#{SecureRandom.uuid}"] }
    let!(:workflow) do
      flow = described_class.new
      flow.parent_id = SecureRandom.uuid
      flow.outgoing = outgoing
      flow
    end
    let(:item) do
      Dwf::Item.new(
        workflow_id: SecureRandom.uuid,
        id: SecureRandom.uuid,
        started_at: started_at
      )
    end
    before do
      allow(item).to receive(:persist_and_perform_async!)
      workflow.enqueue_outgoing_jobs
    end

    context 'outgoing jobs ready to start' do
      let(:started_at) { nil }
      it { expect(item).to have_received(:persist_and_perform_async!) }
    end

    context 'outgoing jobs havent ready to start' do
      let(:started_at) { Time.now.to_i }
      it { expect(item).not_to have_received(:persist_and_perform_async!) }
    end
  end
end
