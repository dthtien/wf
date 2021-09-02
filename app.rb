require 'mechanize'
require 'sidekiq'
require 'sidekiq-pro'
require "active_record"
require "logger"
require 'redis'
require 'byebug'
require 'json'
require_relative "lib/workers.rb"
require_relative './lib/wf/workflow'

class TestWf < Wf::Workflow
  def configure
    run A
    run B, after: A
    run C, after: A
    run E, after: [B, C]
    run D, after: [E]
  end
end

wf = TestWf.create
wf.start!
