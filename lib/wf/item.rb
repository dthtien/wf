module Wf
  class Item
    attr_reader :workflow_id, :id, :params, :queue, :klass
    attr_accessor :incomming, :outgoing

    def initialize(workflow_id:, id:, params: {}, queue: 'wf', klass: self.class)
      @workflow_id = workflow_id
      @id = id
      @params = params
      @queue = queue
      @incomming = []
      @outgoing = []
      @klass = klass
    end

    def name
      @name ||= "#{klass}|#{id}"
    end
  end
end
