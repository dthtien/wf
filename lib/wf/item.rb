require_relative 'client'

module Wf
  class Item
    attr_reader :workflow_id, :id, :params, :queue, :klass, :started_at,
      :enqueued_at, :finished_at, :failed_at
    attr_accessor :incomming, :outgoing

    def initialize(options = {})
      @workflow_id = options[:workflow_id]
      @id = options[:id]
      @params = options[:params]
      @queue = options[:queue] || 'wf'
      @incomming = options[:incoming] || []
      @outgoing = options[:outgoing] || []
      @klass = options[:klass] || self.class
      @finished_at = options[:finished_at]
      @enqueued_at = options[:enqueued_at]
      @started_at = options[:started_at]
    end

    def self.from_hash(hash)
      hash[:klass].constantize.new(hash)
    end

    def persist_and_perform_async!
      enqueue!
      persist!
      perform_async
    end

    def perform; end

    def perform_async
      Wf::Worker.set(queue: queue).perform_async(workflow_id, name)
    end

    def name
      @name ||= "#{klass}|#{id}"
    end

    def no_dependencies?
      incomming.empty?
    end

    def parents_succeeded?
      incomming.all? do |name|
        client.find_job(workflow_id, name).succeeded?
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
        check_or_lock(job_name)
        out = client.find_job(workflow_id, job_name)
        out.persist_and_perform_async! if out.ready_to_start?
        release_lock(job_name)
      end
    end

    def check_or_lock(job_name)
      key = "gush_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}"

      if client.key_exists?(key)
        sleep 2
      else
        client.set(key, 'running')
      end
    end

    def release_lock(job_name)
      client.delete("gush_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}")
    end

    def to_hash
      {
        id: id,
        klass: klass.to_s,
        queue: queue,
        incoming: incomming,
        outgoing: outgoing,
        finished_at: finished_at,
        enqueued_at: enqueued_at,
        started_at: started_at,
        failed_at: failed_at,
        params: params,
        workflow_id: workflow_id
      }
    end

    def as_json
      to_hash.to_json
    end

    def persist!
      client.persist_job(self)
    end

    private

    def client
      @client ||= Wf::Client.new
    end
  end
end
