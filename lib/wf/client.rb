module Wf
  class Client
    def find_job(workflow_id, job_name)
      job_name_match = /(?<klass>\w*[^-])-(?<identifier>.*)/.match(job_name)
      data = if job_name_match
               find_job_by_klass_and_id(workflow_id, job_name)
             else
               find_job_by_klass(workflow_id, job_name)
             end

      return nil if data.nil?

      data = JSON.parse(data)
      Wf::Item.from_hash(Wf::Utils.symbolize_keys(data))
    end

    def persist_job(job)
      redis.hset("wf.jobs.#{job.workflow_id}.#{job.klass}", job.id, job.as_json)
    end

    def check_or_lock(workflow_id, job_name)
      key = "wf_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}"

      if key_exists?(key)
        sleep 2
      else
        set(key, 'running')
      end
    end

    def release_lock(workflow_id, job_name)
      delete("wf_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}")
    end

    def persist_workflow(workflow)
      redis.set("wf.workflows.#{workflow.id}", workflow.as_json)
    end

    def build_job_id(workflow_id, job_klass)
      jid = nil

      loop do
        jid = SecureRandom.uuid
        available = !redis.hexists(
          "wf.jobs.#{workflow_id}.#{job_klass}",
          jid
        )

        break if available
      end

      jid
    end

    def build_workflow_id
      wid = nil
      loop do
        wid = SecureRandom.uuid
        available = !redis.exists?("wf.workflow.#{wid}")

        break if available
      end

      wid
    end

    def key_exists?(key)
      redis.exists?(key)
    end

    def set(key, value)
      redis.set(key, value)
    end

    def delete(key)
      redis.del(key)
    end

    private

    def find_job_by_klass_and_id(workflow_id, job_name)
      job_klass, job_id = job_name.split('|')

      redis.hget("wf.jobs.#{workflow_id}.#{job_klass}", job_id)
    end

    def find_job_by_klass(workflow_id, job_name)
      _new_cursor, result = redis.hscan("wf.jobs.#{workflow_id}.#{job_name}", 0, count: 1)
      return nil if result.empty?

      _job_id, job = *result[0]

      job
    end

    def redis
      @redis ||= Redis.new
    end
  end
end
