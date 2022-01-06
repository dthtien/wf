# frozen_string_literal: true

module Dwf
  class CLI
    ACTIONS = [
      SHOW = 'show'
    ].freeze

    def initialize(arguments)
      @action, @id = arguments
    end

    def call
      return puts 'Command not found' unless ACTIONS.include?(action)

      send action
    end

    private

    attr_reader :action, :id

    def show
      flow = client.find_workflow(id)
      pp flow
    rescue WorkflowNotFound
      puts 'Workflow not found!'
    end

    def client
      @client ||= Client.new
    end
  end
end
