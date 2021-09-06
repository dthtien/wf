require_relative 'client'

module Dwf
  class Callback
    def process_next_step(status, options)
      previous_job_names = options['names']
      workflow_id = options['workflow_id']
      processing_job_names = previous_job_names.map do |job_name|
        job = client.find_job(workflow_id, job_name)
        job.outgoing
      end.flatten.uniq
      return if processing_job_names.empty?

      overall = Sidekiq::Batch.new(status.parent_bid)
      overall.jobs { setup_batch(processing_job_names, workflow_id) }
    end

    def start(job)
      job.outgoing.any? ? start_with_batch(job) : job.perform_async
    end

    private

    def setup_batch(processing_job_names, workflow_id)
      jobs = fetch_jobs(processing_job_names, workflow_id)
      jobs_classification = classify_jobs jobs

      jobs_classification.values.each do |batch_jobs|
        batch = Sidekiq::Batch.new
        batch.on(
          :success,
          'Dwf::Callback#process_next_step',
          names: batch_jobs.map(&:klass),
          workflow_id: workflow_id
        )

        batch.jobs do
          batch_jobs.each do |job|
            job.persist_and_perform_async! if job.ready_to_start?
          end
        end
      end
    end

    def classify_jobs(jobs)
      hash = {}
      jobs.each do |job|
        outgoing_jobs = job.outgoing
        key = outgoing_jobs.empty? ? 'default_key' : outgoing_jobs.join

        if hash[key].nil?
          hash[key] = [job]
        else
          hash[key] = hash[key].push(job)
        end
      end

      hash
    end

    def fetch_jobs(processing_job_names, workflow_id)
      processing_job_names.map do |job_name|
        client.find_job(workflow_id, job_name)
      end.compact
    end

    def perform_job(job_name, workflow_id)
      with_lock workflow_id, job_name do
        job = client.find_job(workflow_id, job_name)
        job.persist_and_perform_async! if job.ready_to_start?
      end
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
