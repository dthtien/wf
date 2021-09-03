require 'mechanize'
require 'sidekiq'
require "active_record"
require "logger"
require 'sidekiq-pro'
require_relative './wf/item'

class A < Wf::Item
  def perform
    puts "#{self.class.name} Working"
    sleep 2
    puts "#{self.class.name} Finished"
  end
end

class E < A
end
class B < A; end
class C < E; end
class D < E; end

