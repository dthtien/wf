# frozen_string_literal: true

require_relative 'client'
require_relative 'worker'
require_relative 'callback'

module Dwf
  class Workflow
    CALLBACK_TYPES = [
      BUILD_IN = 'build-in',
      SK_BATCH = 'sk-batch'
    ].freeze
    attr_reader :dependencies, :jobs, :started_at, :finished_at, :persisted, :stopped,
                :callback_type

    class << self
      def create(*args)
        flow = new(*args)
        flow.save
        flow
      end
    end

    def initialize(options = {})
      @dependencies = []
      @id = id
      @jobs = []
      @persisted = false
      @stopped = false
      @callback_type = options[:callback_type] || BUILD_IN

      setup
    end

    def start!
      initial_jobs.each do |job|
        cb_build_in? ? job.persist_and_perform_async! : Dwf::Callback.new.start(job)
      end
    end

    def save
      client.persist_workflow(self)
      jobs.each(&:persist!)
      mark_as_persisted
      true
    end

    def cb_build_in?
      callback_type == BUILD_IN
    end

    def id
      @id ||= client.build_workflow_id
    end

    def configure; end

    def run(klass, options = {})
      node = klass.new(
        workflow_id: id,
        id: client.build_job_id(id, klass.to_s),
        params: options.fetch(:params, {}),
        queue: options[:queue],
        callback_type: callback_type
      )

      jobs << node

      build_dependencies_structure(node, options)
      node.name
    end

    def find_job(name)
      match_data = /(?<klass>\w*[^-])-(?<identifier>.*)/.match(name.to_s)

      if match_data.nil?
        job = jobs.find { |node| node.klass.to_s == name.to_s }
      else
        job = jobs.find { |node| node.name.to_s == name.to_s }
      end

      job
    end

    def to_hash
      name = self.class.to_s
      {
        name: name,
        id: id,
        arguments: @arguments,
        total: jobs.count,
        finished: jobs.count(&:finished?),
        klass: name,
        status: status,
        stopped: stopped,
        started_at: started_at,
        finished_at: finished_at,
        callback_type: callback_type
      }
    end

    def as_json
      to_hash.to_json
    end

    def finished?
      jobs.all?(&:finished?)
    end

    def started?
      !!started_at
    end

    def running?
      started? && !finished?
    end

    def failed?
      jobs.any?(&:failed?)
    end

    def stopped?
      stopped
    end

    def status
      return :failed if failed?
      return :running if running?
      return :finished if finished?
      return :stopped if stopped?

      :running
    end

    def mark_as_persisted
      @persisted = true
    end

    def mark_as_started
      @stopped = false
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

        to.incoming << dependency[:from]
        from.outgoing << dependency[:to]
      end
    end

    def build_dependencies_structure(node, options)
      deps_after = [*options[:after]]

      deps_after.each do |dep|
        @dependencies << { from: dep.to_s, to: node.name.to_s }
      end

      deps_before = [*options[:before]]

      deps_before.each do |dep|
        @dependencies << { from: node.name.to_s, to: dep.to_s }
      end
    end

    def client
      @client ||= Dwf::Client.new
    end
  end
end
