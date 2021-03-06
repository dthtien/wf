# frozen_string_literal: true

require 'spec_helper'

describe Dwf::Item, item: true do
  let!(:id) { SecureRandom.uuid }
  let!(:workflow_id) { SecureRandom.uuid }
  let(:incoming) { [] }
  let(:outgoing) { [] }
  let(:started_at) { nil }
  let(:finished_at) { nil }
  let(:options) do
    {
      workflow_id: workflow_id,
      id: id,
      params: {},
      incoming: incoming,
      outgoing: outgoing,
      queue: Dwf::Configuration::NAMESPACE,
      klass: 'Dwf::Item',
      started_at: started_at,
      finished_at: finished_at,
      callback_type: Dwf::Workflow::BUILD_IN,
      payloads: nil
    }
  end
  let!(:item) { described_class.new(options) }

  describe 'self.from_hash' do
    let!(:item) { described_class.from_hash(options) }
    it { expect(item.to_hash.compact).to eq options.compact }
  end

  describe '#persist_and_perform_async!' do
    let(:worker_double) { double(perform_async: nil) }
    let(:client_double) { double(persist_job: nil) }

    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      allow(Dwf::Worker).to receive(:set).and_return worker_double
      item.persist_and_perform_async!
    end

    it do
      expect(worker_double)
        .to have_received(:perform_async)
        .with(item.workflow_id, item.name)
      expect(client_double).to have_received(:persist_job).with(item)
      expect(item.enqueued_at).not_to be_nil
    end
  end

  describe '#cb_build_in?' do
    it { expect(item.cb_build_in?).to be_truthy }
  end

  describe '#perform_async' do
    let(:worker_double) { double(perform_async: nil) }
    before do
      allow(Dwf::Worker).to receive(:set).and_return worker_double
      item.perform_async
    end

    it do
      expect(worker_double)
        .to have_received(:perform_async)
        .with(item.workflow_id, item.name)
    end
  end

  describe '#name' do
    it { expect(item.name).to eq "#{described_class}|#{id}" }
  end

  describe '#no_dependencies?' do
    it { expect(item.no_dependencies?).to be_truthy }
  end

  describe '#parents_succeeded?' do
    let(:incoming) { ["A|#{SecureRandom.uuid}"] }
    let(:client_double) { double(find_job: nil) }
    let(:a_item) do
      described_class.new(
        workflow_id: SecureRandom.uuid,
        id: SecureRandom.uuid,
        finished_at: finished_at
      )
    end

    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      allow(client_double)
        .to receive(:find_node).and_return a_item
    end

    context 'parent jobs already finished' do
      let(:finished_at) { Time.now.to_i }

      it do
        expect(item.parents_succeeded?).to be_truthy
        expect(client_double)
          .to have_received(:find_node)
          .with(incoming.first, workflow_id)
      end
    end

    context 'parent jobs havent finished yet' do
      let(:finished_at) { nil }

      it do
        expect(item.parents_succeeded?).to be_falsy
        expect(client_double)
          .to have_received(:find_node)
          .with(incoming.first, workflow_id)
      end
    end
  end

  describe '#enqueue!' do
    before { item.enqueue! }

    it { expect(item.enqueued_at).not_to be_nil }
  end

  describe '#mark_as_started' do
    let(:client_double) { double(persist_job: nil) }
    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      item.mark_as_started
    end

    it do
      expect(client_double).to have_received(:persist_job).with item
      expect(item.started_at).not_to be_nil
    end
  end

  describe '#mark_as_finished' do
    let(:client_double) { double(persist_job: nil) }
    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      item.mark_as_finished
    end

    it do
      expect(client_double).to have_received(:persist_job).with item
      expect(item.finished_at).not_to be_nil
    end
  end

  describe '#enqueue_outgoing_jobs' do
    let(:client_double) do
      double(
        find_node: nil,
        check_or_lock: nil,
        release_lock: nil,
        build_workflow_id: SecureRandom.uuid
      )
    end

    context 'when item is not a leaf' do
      let(:outgoing) { ["A|#{SecureRandom.uuid}"] }
      let(:a_item) do
        described_class.new(
          workflow_id: SecureRandom.uuid,
          id: SecureRandom.uuid,
          started_at: started_at
        )
      end
      before do
        allow(Dwf::Client).to receive(:new).and_return client_double
        allow(a_item).to receive(:persist_and_perform_async!)
        allow(client_double)
          .to receive(:find_node).and_return a_item
        item.enqueue_outgoing_jobs
      end

      it do
        expect(client_double).to have_received(:check_or_lock) do |&block|
          expect(block).to be_kind_of Proc
        end
      end
    end

    context 'when item is a leaf' do
      let(:leaf) { true }
      let(:workflow) { Dwf::Workflow.new }
      before do
        allow(Dwf::Client).to receive(:new).and_return client_double
        allow(client_double).to receive(:find_workflow).and_return workflow
        allow(workflow).to receive(:enqueue_outgoing_jobs)
        item.enqueue_outgoing_jobs
      end

      let(:started_at) { nil }
      it { expect(workflow).to have_received(:enqueue_outgoing_jobs) }
    end
  end

  describe '#output' do
    before { item.output(1) }

    it { expect(item.output_payload).to eq 1 }
  end

  describe '#payloads' do
    let(:incoming) { ["Dwf::Item|#{SecureRandom.uuid}", "Dwf::Workflow|#{workflow_id}"] }
    let(:client_double) { double(find_job: nil, build_workflow_id: workflow_id) }
    let(:workflow) { Dwf::Workflow.new }
    let!(:a_item) do
      described_class.new(
        workflow_id: SecureRandom.uuid,
        id: SecureRandom.uuid,
        finished_at: finished_at,
        output_payload: 1
      )
    end

    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      allow(client_double)
        .to receive(:find_node)
        .with(incoming.first, workflow_id).and_return a_item
      allow(client_double)
        .to receive(:find_node)
        .with(incoming.last, workflow_id).and_return workflow
    end

    it do
      expected_payload = [
        {
          class: a_item.class.name,
          id: a_item.name,
          output: 1
        },
        {
          class: workflow.class.name,
          id: workflow.name,
          output: []
        }
      ]
      expect(item.payloads).to match_array expected_payload
    end
  end

  describe '#start_batch!' do
    let(:callback_double) { double(start: nil) }
    let(:client_double) { double(persist_job: nil) }

    before do
      allow(Dwf::Client).to receive(:new).and_return client_double
      allow(Dwf::Callback).to receive(:new).and_return callback_double
      item.start_batch!
    end

    it do
      expect(callback_double).to have_received(:start).with(item)
      expect(item.enqueued_at).not_to be_nil
    end
  end

  describe '#leaf?' do
    context 'when item has outgoing item' do
      let(:outgoing) { ["Dwf::Item|#{SecureRandom.uuid}"] }
      it { expect(item.leaf?).to be_falsy }
    end

    context 'when item does not have outgoing item' do
      let(:outgoing) { [] }
      it { expect(item.leaf?).to be_truthy }
    end
  end
end
