module Dwf
  module Concerns
    module Checkable
      def no_dependencies?
        incoming.empty?
      end

      def ready_to_start?
        !running? && !enqueued? && !finished? && !failed? && parents_succeeded?
      end

      def succeeded?
        finished? && !failed?
      end

      def running?
        started? && !finished?
      end

      def started?
        !!started_at
      end
    end
  end
end
