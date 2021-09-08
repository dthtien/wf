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
require_relative 'dwf/configuration'

module Dwf
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.config
    yield configuration
  end
end

