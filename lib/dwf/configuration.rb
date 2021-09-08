# frozen_string_literal: true

module Dwf
  class Configuration
    NAMESPACE = 'dwf'
    CONCURRENCY = 5
    REDIS_URL = 'redis://localhost:6379'
    TTL = -1

    attr_accessor :redis_url, :concurrency, :namespace, :ttl

    def initialize(hash = {})
      @concurrency = hash.fetch(:concurrency, CONCURRENCY)
      @namespace   = hash.fetch(:namespace, NAMESPACE)
      @redis_url   = hash.fetch(:redis_url, REDIS_URL)
      @ttl         = hash.fetch(:ttl, TTL)
    end
  end
end
