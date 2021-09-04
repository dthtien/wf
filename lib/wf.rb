# frozen_string_literal: true
require "bundler/setup"

require 'sidekiq'
require 'sidekiq-pro'
require 'json'
require 'redis'

require_relative 'wf/utils'
require_relative 'wf/workflow'
require_relative 'wf/item'
require_relative 'wf/client'
require_relative 'wf/worker'
require_relative 'wf/callback'

module Wf
  VERSION = '0.1.0'
end

