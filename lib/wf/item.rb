module Wf
  class Item
    attr_reader :workflow_id, :id, :params, :queue, :klass, :workflow, :started_at,
      :enqueued_at, :finished_at, :failed_at
    attr_accessor :incomming, :outgoing

    def initialize(workflow_id:, id:, params: {}, queue: 'wf', klass: self.class, workflow: )
      @workflow_id = workflow_id
      @id = id
      @params = params
      @queue = queue
      @incomming = []
      @outgoing = []
      @klass = klass
      @workflow = workflow
    end

    def perform
      return enqueue_outgoing_jobs if succeeded?

      puts "sleeping #{self.class.name}"
      sleep 2
      puts "Wake up #{self.class.name}"

      finish!
      enqueue_outgoing_jobs
    end

    def name
      @name ||= "#{klass}|#{id}"
    end

    def no_dependencies?
      incomming.empty?
    end

    def parents_succeeded?
      incomming.none? do |name|
        !workflow.find_job(name).succeeded?
      end
    end

    def enqueue!
      @enqueued_at = current_timestamp
      @started_at = nil
      @finished_at = nil
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
      jdata = outgoing.map do |job_name|
        Thread.new do
          out = workflow.find_job(job_name)

          if out.ready_to_start?
            out.enqueue!
            out.perform
          end
        end
      end

      jdata.each(&:join)
    end
  end
end
