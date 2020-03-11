# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Sneakers uses Sneakers::Worker::Classes array to track all workers.
  # WorkersRegistry mocks original array to track ActiveJob workers separately.
  class WorkersRegistry
    attr_reader :sneakers_workers, :activejob_workers

    delegate :activejob_workers_strategy, to: :'AdvancedSneakersActiveJob.config'

    def initialize
      @sneakers_workers = []
      @activejob_workers = []
    end

    def <<(worker)
      if worker <= ActiveJob::QueueAdapters::AdvancedSneakersAdapter::JobWrapper
        activejob_workers << worker
      else
        sneakers_workers << worker
      end
    end

    # See https://github.com/jondot/sneakers/blob/7a972d22a58de8a261a738d9a1e5fb51f9608ede/lib/sneakers/workergroup.rb#L28
    def call
      case activejob_workers_strategy
      when :only
        activejob_workers
      when :exclude
        sneakers_workers
      when :include
        sneakers_workers + activejob_workers
      else
        raise "Unknown activejob_workers_strategy '#{activejob_workers_strategy}'"
      end
    end

    def empty?
      call.empty?
    end

    def inspect
      {
        sneakers_workers: sneakers_workers,
        activejob_workers: activejob_workers
      }
    end
  end
end
