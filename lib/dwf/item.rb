# frozen_string_literal: true

require_relative 'client'
require_relative 'concerns/checkable'

module Dwf
  class Item
    include Concerns::Checkable

    attr_reader :workflow_id, :id, :params, :queue, :klass, :started_at,
                :enqueued_at, :finished_at, :failed_at, :output_payload
    attr_writer :payloads
    attr_accessor :incoming, :outgoing, :callback_type

    def initialize(options = {})
      assign_attributes(options)
    end

    def self.from_hash(hash)
      Module.const_get(hash[:klass]).new(hash)
    end

    def start_initial!
      cb_build_in? ? persist_and_perform_async! : start_batch!
    end

    def start_batch!
      enqueue_and_persist!
      Dwf::Callback.new.start(self)
    end

    def persist_and_perform_async!
      enqueue_and_persist!
      perform_async
    end

    def perform; end

    def cb_build_in?
      callback_type == Dwf::Workflow::BUILD_IN
    end

    def workflow
      @workflow ||= client.find_workflow(workflow_id)
    end

    def reload
      item = client.find_job(workflow_id, name)
      assign_attributes(item.to_hash)
    end

    def perform_async
      Dwf::Worker.set(queue: queue || client.config.namespace)
        .perform_async(workflow_id, name)
    end

    def name
      @name ||= "#{klass}|#{id}"
    end

    def output(data)
      @output_payload = data
    end

    def no_dependencies?
      incoming.empty?
    end

    def parents_succeeded?
      incoming.all? { |name| client.find_node(name, workflow_id).succeeded? }
    end

    def payloads
      @payloads ||= build_payloads
    end

    def enqueue!
      @enqueued_at = current_timestamp
      @started_at = nil
      @finished_at = nil
      @failed_at = nil
    end

    def mark_as_started
      start!
      persist!
    end

    def mark_as_finished
      finish!
      persist!
    end

    def start!
      @started_at = current_timestamp
      @failed_at = nil
    end

    def finish!
      @finished_at = current_timestamp
    end

    def fail!
      @finished_at = @failed_at = current_timestamp
    end

    def enqueued?
      !enqueued_at.nil?
    end

    def finished?
      !finished_at.nil?
    end

    def failed?
      !failed_at.nil?
    end

    def current_timestamp
      Time.now.to_i
    end

    def enqueue_outgoing_jobs
      if leaf?
        return unless workflow.sub_workflow?

        workflow.outgoing.each do |job_name|
          client.check_or_lock(workflow.parent_id, job_name)
          out = client.find_node(job_name, workflow.parent_id)
          out.persist_and_perform_async! if out.ready_to_start?
          client.release_lock(workflow.parent_id, job_name)
        end
      else
        outgoing.each do |job_name|
          client.check_or_lock(workflow_id, job_name)
          out = client.find_node(job_name, workflow_id)
          out.persist_and_perform_async! if out.ready_to_start?
          client.release_lock(workflow_id, job_name)
        end
      end
    end

    def to_hash
      {
        id: id,
        klass: klass.to_s,
        queue: queue,
        incoming: incoming,
        outgoing: outgoing,
        finished_at: finished_at,
        enqueued_at: enqueued_at,
        started_at: started_at,
        failed_at: failed_at,
        params: params,
        workflow_id: workflow_id,
        callback_type: callback_type,
        output_payload: output_payload,
        payloads: @payloads
      }
    end

    def as_json
      to_hash.to_json
    end

    def persist!
      client.persist_job(self)
    end

    private

    def enqueue_and_persist!
      enqueue!
      persist!
    end

    def client
      @client ||= Dwf::Client.new
    end

    def assign_attributes(options)
      @workflow_id = options[:workflow_id]
      @id = options[:id]
      @params = options[:params]
      @queue = options[:queue]
      @incoming = options[:incoming] || []
      @outgoing = options[:outgoing] || []
      @klass = options[:klass] || self.class
      @failed_at = options[:failed_at]
      @finished_at = options[:finished_at]
      @enqueued_at = options[:enqueued_at]
      @started_at = options[:started_at]
      @callback_type = options[:callback_type]
      @output_payload = options[:output_payload]
      @payloads = options[:payloads]
    end

    def build_payloads
      data = incoming.map do |job_name|
        node = client.find_node(job_name, workflow_id)
        next if node.output_payload.nil?

        {
          id: node.name,
          class: node.klass.to_s,
          output: node.output_payload
        }
      end.compact
      data.empty? ? nil : data
    end
  end
end
