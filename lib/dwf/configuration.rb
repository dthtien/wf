# frozen_string_literal: true

module Dwf
  class Configuration
    NAMESPACE = 'dwf'
    REDIS_OPTS = { url: 'redis://localhost:6379' }.freeze

    attr_accessor :redis_opts, :namespace

    def initialize(hash = {})
      @namespace = hash.fetch(:namespace, NAMESPACE)
      @redis_opts = hash.fetch(:redis_options, REDIS_OPTS)
    end
  end
end
