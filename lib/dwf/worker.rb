# frozen_string_literal: true

require 'sidekiq'
require_relative 'client'

module Dwf
  class Worker
    include Sidekiq::Worker

    def perform(workflow_id, job_name)
      job = client.find_job(workflow_id, job_name)
      return job.enqueue_outgoing_jobs if job.succeeded?

      job.mark_as_started
      job.perform
      job.mark_as_finished
      job.enqueue_outgoing_jobs if job.cb_build_in?
    end

    private

    def client
      @client ||= Dwf::Client.new
    end
  end
end
