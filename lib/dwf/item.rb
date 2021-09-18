# frozen_string_literal: true

require_relative 'client'

module Dwf
  class Item
    attr_reader :workflow_id, :id, :params, :queue, :klass, :started_at,
      :enqueued_at, :finished_at, :failed_at, :callback_type, :output_payload
    attr_accessor :incoming, :outgoing

    def initialize(options = {})
      assign_attributes(options)
    end

    def self.from_hash(hash)
      Module.const_get(hash[:klass]).new(hash)
    end

    def persist_and_perform_async!
      enqueue!
      persist!
      perform_async
    end

    def perform; end

    def cb_build_in?
      callback_type == Dwf::Workflow::BUILD_IN
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
      incoming.all? do |name|
        if name.downcase.include?('workflow')
          _, fid = name.split('|')
          client.find_workflow(fid).succeeded?
        else
          client.find_job(workflow_id, name).succeeded?
        end
      end
    end

    def payloads
      incoming.map do |job_name|
        job = client.find_job(workflow_id, job_name)
        {
          id: job.name,
          class: job.klass.to_s,
          output: job.output_payload
        }
      end
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

    def succeeded?
      finished? && !failed?
    end

    def started?
      !started_at.nil?
    end

    def running?
      started? && !finished?
    end

    def ready_to_start?
      !running? && !enqueued? && !finished? && !failed? && parents_succeeded?
    end

    def current_timestamp
      Time.now.to_i
    end

    def enqueue_outgoing_jobs
      outgoing.each do |job_name|
        client.check_or_lock(workflow_id, job_name)
        out = client.find_job(workflow_id, job_name)
        out.persist_and_perform_async! if out.ready_to_start?
        client.release_lock(workflow_id, job_name)
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
        output_payload: output_payload
      }
    end

    def as_json
      to_hash.to_json
    end

    def persist!
      client.persist_job(self)
    end

    def workflow?
      false
    end

    private

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
    end
  end
end
