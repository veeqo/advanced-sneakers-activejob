# frozen_string_literal: true

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

    it 'allows to replace :sneakers adapter with :advanced_sneakers adapter without' do
      # :sneakers adapter creates consumer for "default" queue and all jobs are processed within it
      ensure_application_job_works_with_sneakers
      expect(rabbitmq_queues).to include(expected_default_queue)

      # :advanced_sneakers adapter should cover same functionality
      ensure_application_job_works_with_advanced_sneakers
      expect(rabbitmq_queues).to include(expected_default_queue)
      expect(logs('sneakers')).not_to match(/precondition/i)
    end

    def ensure_application_job_works_with_sneakers
      cleanup_logs
      start_sneakers_consumers('with_sneakers_adapter')

      in_child_process('with_sneakers_adapter') do
        ApplicationJob.perform_later('sneakers')
        sleep(0.05)
      end

      expect(logs('rails')).to include('Performing ApplicationJob from Sneakers(default) with arguments: "sneakers"')

      stop_sneakers_consumers
    end

    def ensure_application_job_works_with_advanced_sneakers
      cleanup_logs
      start_sneakers_consumers('with_advanced_sneakers_adapter')

      in_child_process('with_advanced_sneakers_adapter') do
        ApplicationJob.perform_later('advanced sneakers')
        sleep(0.05)
      end

      expect(logs('rails')).to include('Performing ApplicationJob from AdvancedSneakers(default) with arguments: "advanced sneakers"')

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

    it 'allows to replace :sneakers adapter with :advanced_sneakers adapter without' do
      # :sneakers adapter creates consumer only for "default" queue and all jobs for other queue are LOST
      ensure_custom_queue_job_does_not_with_sneakers
      expect(rabbitmq_queues).not_to include(expected_custom_queue)

      # :advanced_sneakers adapter should work
      ensure_custom_queue_job_works_with_advanced_sneakers
      expect(rabbitmq_queues).to include(expected_custom_queue)
    end

    def ensure_custom_queue_job_does_not_with_sneakers
      cleanup_logs
      start_sneakers_consumers('with_sneakers_adapter')

      in_child_process('with_sneakers_adapter') do
        CustomQueueJob.perform_later('sneakers')
        sleep(0.05)
      end

      expect(logs('rails')).to include('Enqueued CustomQueueJob')
      expect(logs('rails')).not_to include('Performing CustomQueueJob')

      stop_sneakers_consumers
    end

    def ensure_custom_queue_job_works_with_advanced_sneakers
      cleanup_logs
      start_sneakers_consumers('with_advanced_sneakers_adapter')

      in_child_process('with_advanced_sneakers_adapter') do
        CustomQueueJob.perform_later('advanced sneakers')
        sleep(0.05)
      end

      expect(logs('rails')).to include('Enqueued CustomQueueJob')
      expect(logs('rails')).to include('Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "advanced sneakers"')

      stop_sneakers_consumers
    end
  end
end
