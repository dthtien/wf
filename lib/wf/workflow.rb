require 'redis'

module Wf
  class Workflow
    attr_reader :dependencies, :jobs

    def initialize
      @dependencies = []
      @id = id
      @jobs = []

      setup
    end

    def start!
      initial_jobs.each do |job|
        Thread.new do
          job.enqueue!
          job.perform
        end.join
      end
    end

    def configure; end

    def run(klass, options = {})
      node = klass.new(
        workflow_id: id,
        id: job_id(id, klass.to_s),
        params: options.fetch(:params, {}),
        queue: options[:queue],
        workflow: self
      )

      jobs << node

      deps_after = [*options[:after]]

      deps_after.each do |dep|
        @dependencies << { from: dep.to_s, to: node.name.to_s }
      end

      deps_before = [*options[:before]]

      deps_before.each do |dep|
        @dependencies << { from: node.name.to_s, to: dep.to_s }
      end

      node.name
    end

    def find_job(name)
      if /(?<klass>\w*[^-])-(?<identifier>.*)/.match(name.to_s)
        job = jobs.find { |node| node.name.to_s == name.to_s }
      else
        job = jobs.find { |node| node.klass.to_s == name.to_s }
      end

      job
    end

    private

    def initial_jobs
      jobs.select(&:no_dependencies?)
    end

    def setup
      configure
      resolve_dependencies
    end

    def resolve_dependencies
      @dependencies.each do |dependency|
        from = find_job(dependency[:from])
        to   = find_job(dependency[:to])

        to.incomming << dependency[:from]
        from.outgoing << dependency[:to]
      end
    end

    def job_id(workflow_id, job_klass)
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

    def id
      @id ||=
        begin
          wid = nil
          loop do
            wid = SecureRandom.uuid
            available = !redis.exists?("wf.workflow.#{wid}")

            break if available
          end

          wid
        end
    end

    def redis
      @redis ||= Redis.new
    end
  end
end
