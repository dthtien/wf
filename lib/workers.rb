require 'mechanize'
require 'sidekiq'
require "active_record"
require "logger"
require 'sidekiq-pro'
require_relative './wf/item'

class A < Wf::Item; end

class E < A
end
class B < A; end
class C < E; end
class D < E; end

