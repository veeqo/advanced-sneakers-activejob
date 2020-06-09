# frozen_string_literal: true

module AdvancedSneakersActiveJob
  module Support
    class LocateWorkersByQueues
      def initialize(queues)
        @queues = queues.uniq.reject(&:blank?)
        @queues_without_workers = []
        @workers = []
      end

      def call
        detect_workers_for_queues!
        ensure_all_workers_found!

        @workers
      end

      private

      def ensure_all_workers_found!
        return if @queues_without_workers.empty?

        raise("Missing workers for queues: #{@queues_without_workers.join(', ')}")
      end

      def all_workers
        @all_workers ||= Sneakers::Worker::Classes.activejob_workers
      end

      def detect_workers_for_queues!
        @queues.each do |queue|
          worker = all_workers.detect { |klass| klass.queue_name == queue }

          if worker
            @workers << worker
          else
            @queues_without_workers << queue
          end
        end
      end
    end
  end
end
