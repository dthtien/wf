require_relative 'errors'

module Dwf
  class Client
    attr_reader :config

    def initialize(config = Dwf.configuration)
      @config = config
    end

    def find_job(workflow_id, job_name)
      job_name_match = /(?<klass>\w*[^-])-(?<identifier>.*)/.match(job_name)
      data = if job_name_match
               find_job_by_klass_and_id(workflow_id, job_name)
             else
               find_job_by_klass(workflow_id, job_name)
             end

      return nil if data.nil?

      data = JSON.parse(data)
      Dwf::Item.from_hash(Dwf::Utils.symbolize_keys(data))
    end

    def find_workflow(id)
      data = redis.get("dwf.workflows.#{id}")
      raise WorkflowNotFound, "Workflow with given id doesn't exist" if data.nil?

      hash = JSON.parse(data)
      hash = Dwf::Utils.symbolize_keys(hash)
      nodes = parse_nodes(id)
      workflow_from_hash(hash, nodes)
    end

    def persist_job(job)
      redis.hset("dwf.jobs.#{job.workflow_id}.#{job.klass}", job.id, job.as_json)
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
      delete("dwf_enqueue_outgoing_jobs_#{workflow_id}-#{job_name}")
    end

    def persist_workflow(workflow)
      redis.set("dwf.workflows.#{workflow.id}", workflow.as_json)
    end

    def build_job_id(workflow_id, job_klass)
      jid = nil

      loop do
        jid = SecureRandom.uuid
        available = !redis.hexists(
          "dwf.jobs.#{workflow_id}.#{job_klass}",
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
        available = !redis.exists?("dwf.workflow.#{wid}")

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

      redis.hget("dwf.jobs.#{workflow_id}.#{job_klass}", job_id)
    end

    def find_job_by_klass(workflow_id, job_name)
      _new_cursor, result = redis.hscan("dwf.jobs.#{workflow_id}.#{job_name}", 0, count: 1)
      return nil if result.empty?

      _job_id, job = *result[0]

      job
    end

    def parse_nodes(id)
      keys = redis.scan_each(match: "dwf.jobs.#{id}.*")

      keys.map do |key|
        redis.hvals(key).map do |json|
          Dwf::Utils.symbolize_keys JSON.parse(json)
        end
      end.flatten
    end

    def workflow_from_hash(hash, nodes = [])
      flow = Module.const_get(hash[:klass]).new(*hash[:arguments])
      flow.jobs = []
      flow.outgoing = hash.fetch(:outgoing, [])
      flow.incoming = hash.fetch(:incoming, [])
      flow.stopped = hash.fetch(:stopped, false)
      flow.id = hash[:id]
      flow.jobs = nodes.map do |node|
        Dwf::Item.from_hash(node)
      end

      flow
    end

    def redis
      @redis ||= Redis.new(config.redis_opts)
    end
  end
end
