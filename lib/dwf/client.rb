require_relative 'errors'
require 'byebug'

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

    def find_node(name, workflow_id)
      if Utils.workflow_name?(name)
        if name.include?('|')
          _, id = name.split('|')
        else
          id = workflow_id(name, workflow_id)
        end
        find_workflow(id)
      else
        find_job(workflow_id, name)
      end
    end

    def find_workflow(id)
      key = redis.keys("dwf.workflows.#{id}*").first
      data = redis.get(key)
      raise WorkflowNotFound, "Workflow with given id doesn't exist" if data.nil?

      hash = JSON.parse(data)
      hash = Dwf::Utils.symbolize_keys(hash)
      nodes = parse_nodes(id)
      workflow_from_hash(hash, nodes)
    end

    def find_sub_workflow(name, parent_id)
      find_workflow(workflow_id(name, parent_id))
    end

    def sub_workflows(id)
      keys = redis.keys("dwf.workflows.*.*.#{id}")
      keys.map do |key|
        id = key.split('.')[2]

        find_workflow(id)
      end
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
      key = [
        'dwf', 'workflows', workflow.id, workflow.class.name, workflow.parent_id
      ].compact.join('.')
      redis.set(key, workflow.as_json)
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

    def workflow_id(name, parent_id)
      key = redis.keys("dwf.workflows.*.#{name}.#{parent_id}").first
      return if key.nil?

      key.split('.')[2]
    end

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

      items = keys.map do |key|
        redis.hvals(key).map do |json|
          node = Dwf::Utils.symbolize_keys JSON.parse(json)
          Dwf::Item.from_hash(node)
        end
      end.flatten
      workflows = sub_workflows(id)
      items + workflows
    end

    def workflow_from_hash(hash, jobs = [])
      flow = Module.const_get(hash[:klass]).new(*hash[:arguments])
      flow.jobs = []
      flow.outgoing = hash.fetch(:outgoing, [])
      flow.parent_id = hash[:parent_id]
      flow.incoming = hash.fetch(:incoming, [])
      flow.stopped = hash.fetch(:stopped, false)
      flow.callback_type = hash.fetch(:callback_type, Workflow::BUILD_IN)
      flow.id = hash[:id]
      flow.jobs = jobs
      flow
    end

    def redis
      @redis ||= Redis.new(config.redis_opts)
    end
  end
end
