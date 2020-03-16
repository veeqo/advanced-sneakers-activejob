# frozen_string_literal: true

# These tests check :adcanced_sneakers adapter might be a replacement for :sneakers adapter.
# Most important is to verify that _same_ setup of RabbitMQ is used and on PRECONDITION FAILED errors appear.

describe 'Backward compatibility', :rabbitmq do
  context 'when worker has no queue name defined' do
    let(:expected_default_queue) do
      {
        'arguments' => {},
        'auto_delete' => false,
        'durable' => true,
        'exclusive' => false,
        'name' => 'default'
      }
    end

    it 'allows drop-in replacement of :sneakers adapter with :advanced_sneakers adapter' do
      # :sneakers adapter creates consumer for "default" queue and all jobs are processed within it
      ensure_application_job_works_with_sneakers
      expect(rabbitmq_queues).to include(expected_default_queue)

      # :advanced_sneakers adapter should cover same functionality
      ensure_application_job_works_with_advanced_sneakers
      expect(rabbitmq_queues).to include(expected_default_queue)
      expect_logs(name: 'sneakers', to_exclude: 'PRECONDITION')
    end

    def ensure_application_job_works_with_sneakers
      cleanup_logs
      start_sneakers_consumers(adapter: :sneakers)
      in_app_process(adapter: :sneakers) { ApplicationJob.perform_later('sneakers') }

      expect_logs name: 'rails',
                  to_include: 'Performing ApplicationJob from Sneakers(default) with arguments: "sneakers"'

      stop_sneakers_consumers
    end

    def ensure_application_job_works_with_advanced_sneakers
      cleanup_logs
      start_sneakers_consumers(adapter: :advanced_sneakers)
      in_app_process(adapter: :advanced_sneakers) { ApplicationJob.perform_later('advanced sneakers') }

      expect_logs name: 'rails',
                  to_include: 'Performing ApplicationJob from AdvancedSneakers(default) with arguments: "advanced sneakers"'

      stop_sneakers_consumers
    end
  end

  context 'when worker has queue name defined' do
    let(:expected_custom_queue) do
      {
        'arguments' => {},
        'auto_delete' => false,
        'durable' => true,
        'exclusive' => false,
        'name' => 'custom'
      }
    end

    it 'allows drop-in replacement of :sneakers adapter with :advanced_sneakers adapter' do
      # :sneakers adapter creates consumer only for "default" queue and all jobs for other queue are LOST
      ensure_custom_queue_job_does_not_with_sneakers
      expect(rabbitmq_queues).not_to include(expected_custom_queue)

      # :advanced_sneakers adapter should work
      ensure_custom_queue_job_works_with_advanced_sneakers
      expect(rabbitmq_queues).to include(expected_custom_queue)
    end

    def ensure_custom_queue_job_does_not_with_sneakers
      cleanup_logs
      start_sneakers_consumers(adapter: :sneakers)
      in_app_process(adapter: :sneakers) { CustomQueueJob.perform_later('sneakers') }

      expect_logs name: 'rails',
                  to_include: 'Enqueued CustomQueueJob',
                  to_exclude: 'Performing CustomQueueJob'

      stop_sneakers_consumers
    end

    def ensure_custom_queue_job_works_with_advanced_sneakers
      cleanup_logs
      start_sneakers_consumers(adapter: :advanced_sneakers)
      in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('advanced sneakers') }

      expect_logs name: 'rails',
                  to_include: [
                    'Enqueued CustomQueueJob',
                    'Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "advanced sneakers"'
                  ]

      stop_sneakers_consumers
    end
  end

  context 'when worker with :advanced_sneakers adapter receives message published by :sneakers adapter' do
    it 'processes message properly' do
      cleanup_logs
      start_sneakers_consumers(adapter: :advanced_sneakers)
      in_app_process(adapter: :sneakers) { ApplicationJob.perform_later('sneakers') }

      expect_logs name: 'rails',
                  to_include: 'Performing ApplicationJob from AdvancedSneakers(default) with arguments: "sneakers"'

      stop_sneakers_consumers
    end
  end
end
