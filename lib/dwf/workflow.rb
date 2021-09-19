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
    attr_accessor :jobs, :callback_type, :stopped, :id, :incoming, :outgoing, :parent_id
    attr_reader :dependencies, :started_at, :finished_at, :persisted, :arguments, :klass

    class << self
      def create(*args)
        flow = new(*args)
        flow.save
        flow
      end

      def find(id)
        Dwf::Client.new.find_workflow(id)
      end
    end

    def initialize(*args)
      @dependencies = []
      @id = build_id
      @jobs = []
      @persisted = false
      @stopped = false
      @arguments = args
      @parent_id = nil
      @klass = self.class
      @callback_type = SK_BATCH
      @incoming = []
      @outgoing = []

      setup
    end

    def persist!
      client.persist_workflow(self)
      jobs.each(&:persist!)
      mark_as_persisted
      true
    end

    def workflow?
      self.class < Dwf::Workflow
    end

    def name
      "#{self.class.name}|#{id}"
    end

    alias save persist!

    def succeeded?
      finished? && !failed?
    end

    def start!
      mark_as_started
      persist!
      initial_jobs.each do |job|
        cb_build_in? ? job.persist_and_perform_async! : Dwf::Callback.new.start(job)
      end
    end

    alias persist_and_perform_async! start!

    def reload
      flow = self.class.find(id)
      self.stopped = flow.stopped
      self.jobs = flow.jobs

      self
    end

    def cb_build_in?
      callback_type == BUILD_IN
    end

    def build_id
      client.build_workflow_id
    end

    def configure(*arguments); end

    def run(klass, options = {})
      node = if klass < Dwf::Workflow
               flow = klass.new
               flow.parent_id = id
               flow.save
               flow
             else
               klass.new(
                 workflow_id: id,
                 id: client.build_job_id(id, klass.to_s),
                 params: options.fetch(:params, {}),
                 queue: options[:queue],
                 callback_type: callback_type
               )
             end

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
        callback_type: callback_type,
        incoming: incoming,
        outgoing: outgoing,
        parent_id: parent_id
      }
    end

    def ready_to_start?
      true
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

    def no_dependencies?
      incoming.empty?
    end

    private

    def initial_jobs
      jobs.select(&:no_dependencies?)
    end

    def setup
      configure(*@arguments)
      resolve_dependencies
    end

    def find_node(node_name)
      if node_name.downcase.include?('workflow')
        find_subworkflow(node_name)
      else
        find_job(node_name)
      end
    end

    def find_subworkflow(node_name)
      fname, _ = node_name.split('|')
      jobs.find { |j| j.klass.name == fname }
    end

    def resolve_dependencies
      @dependencies.each do |dependency|
        from = find_node(dependency[:from])
        to   = find_node(dependency[:to])

        to.incoming << from.name
        from.outgoing << to.name
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
