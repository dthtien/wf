# frozen_string_literal: true
require "bundler/setup"

require 'sidekiq'
require 'json'
require 'redis'
# require 'sidekiq-pro'

require_relative 'dwf/utils'
require_relative 'dwf/workflow'
require_relative 'dwf/item'
require_relative 'dwf/client'
require_relative 'dwf/worker'
require_relative 'dwf/callback'

module Dwf
  VERSION = '0.1.6'
end

