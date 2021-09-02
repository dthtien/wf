require 'mechanize'
require 'sidekiq'
require "active_record"
require "logger"
require 'sidekiq-pro'
require_relative './wf/item'

class Result < ActiveRecord::Base
end

# Intended to simulate grabbing random data from an HTTP API. Wait a few milliseconds,
# then read some variable data.


class A < Wf::Item
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform
    puts "execute #{self.class.name}"
  end
end

class E < A
  def perform
    sleep 10
    puts "#{self.class.name} wake up"
  end
end
class B < A; end
class C < E; end
class D < E; end

