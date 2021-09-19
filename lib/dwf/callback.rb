# frozen_string_literal: true
require_relative 'client'

module Dwf
  class Callback
    DEFAULT_KEY = 'default_key'

    def process_next_step(status, options)
      previous_job_names = options['names']
      workflow_id = options['workflow_id']
      processing_job_names = previous_job_names.map do |job_name|
        node = client.find_node(job_name, workflow_id)
        node.outgoing
      end.flatten.uniq
      return if processing_job_names.empty?

      overall = Sidekiq::Batch.new(status.parent_bid)
      overall.jobs { setup_batches(processing_job_names, workflow_id) }
    end

    def start(job)
      job.outgoing.any? ? start_with_batch(job) : job.perform_async
    end

    private

    def setup_batches(processing_job_names, workflow_id)
      jobs = fetch_jobs(processing_job_names, workflow_id)
      jobs_classification = classify_jobs jobs

      jobs_classification.each do |key, batch_jobs|
        with_lock workflow_id, key do
          setup_batch(batch_jobs, workflow_id)
        end
      end
    end

    def setup_batch(jobs, workflow_id)
      batch = Sidekiq::Batch.new
      batch.on(
        :success,
        'Dwf::Callback#process_next_step',
        names: jobs.map(&:name),
        workflow_id: workflow_id
      )
      batch.jobs do
        jobs.each do |job|
          job.persist_and_perform_async! if job.ready_to_start?
        end
      end
    end

    def classify_jobs(jobs)
      hash = {}
      jobs.each do |job|
        outgoing_jobs = job.outgoing
        key = outgoing_jobs.empty? ? DEFAULT_KEY : outgoing_jobs.join
        hash[key] = hash[key].nil? ? [job] : hash[key].push(job)
      end

      hash
    end

    def fetch_jobs(processing_job_names, workflow_id)
      processing_job_names.map do |job_name|
        client.find_node(job_name, workflow_id)
      end.compact
    end

    def with_lock(workflow_id, job_name)
      client.check_or_lock(workflow_id, job_name)
      yield
      client.release_lock(workflow_id, job_name)
    end

    def start_with_batch(job)
      batch = Sidekiq::Batch.new
      batch.on(
        :success,
        'Dwf::Callback#process_next_step',
        names: [job.name],
        workflow_id: job.workflow_id
      )
      batch.jobs { job.perform_async }
    end

    def client
      @client ||= Dwf::Client.new
    end
  end
end
