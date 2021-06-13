# frozen_string_literal: true

describe 'Handler', :rabbitmq do
  before { cleanup_logs }

  context 'when job is not failing' do
    subject do
      start_sneakers_consumers(adapter: :advanced_sneakers)
      in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('good job') }
    end

    it 'does not handle job retries' do
      subject

      expect_logs name: 'rails',
                  to_include: [
                    'Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "good job"',
                    'Performed CustomQueueJob from AdvancedSneakers(custom)'
                  ],
                  to_exclude: 'Creating delayed queue'
    end
  end

  context 'when job is failing' do
    context 'when failure is handled by ActiveJob', if: ActiveJob.gem_version >= Gem::Version.new('5.1') do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          CustomQueueJob.discard_on 'StandardError'

          require 'rake'
          require 'sneakers/tasks'
          Rake::Task['sneakers:run'].invoke
        end

        in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('failing job') }
      end

      it 'does not handle job retries' do
        subject

        expect_logs name: 'rails',
                    to_include: [
                      'Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "failing job"',
                      'Discarded CustomQueueJob due to a StandardError'
                    ],
                    to_exclude: 'Creating delayed queue'
      end
    end

    context 'when failure is not handled by ActiveJob' do
      subject do
        start_sneakers_consumers(adapter: :advanced_sneakers)
        in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('failing job') }
      end

      it 'handles job retries' do
        subject

        if ActiveJob.gem_version >= Gem::Version.new('5.1')
          expect_logs name: 'rails',
                      to_include: [
                        'Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "failing job"',
                        'to [activejob-delayed] with routing_key [custom] and delay [3]',
                        'Creating delayed queue'
                      ],
                      to_exclude: 'Performed CustomQueueJob from AdvancedSneakers(custom)'
        else
          expect_logs name: 'rails',
                      to_include: [
                        'Performing CustomQueueJob from AdvancedSneakers(custom) with arguments: "failing job"',
                        'to [activejob-delayed] with routing_key [custom] and delay [3]',
                        'Creating delayed queue'
                      ]
        end
      end

      it 'retries job with exponential backoff' do
        subject
        sleep 0.1

        expect(delayed_queues).to eq(['delayed:3'])

        rabbitmq_messages('delayed:3', ackmode: 'reject_requeue_false') # simulate delayed message timeout
        sleep 0.1

        expect(delayed_queues).to eq(['delayed:3', 'delayed:30'])

        rabbitmq_messages('delayed:30', ackmode: 'reject_requeue_false') # simulate delayed message timeout
        sleep 0.1

        expect(delayed_queues).to eq(['delayed:3', 'delayed:30', 'delayed:90'])
      end

      context 'with max retries' do
        subject do
          in_app_process(adapter: :advanced_sneakers) do
            Sneakers::CONFIG[:max_retries] = 5
            require 'rake'
            require 'sneakers/tasks'
            Rake::Task['sneakers:run'].invoke
          end

          in_app_process(adapter: :advanced_sneakers) { CustomQueueJob.perform_later('failing job') }
        end

        it 'stops retrying' do
          subject
          sleep 0.1

          expect(delayed_queues).to eq(['delayed:3'])

          rabbitmq_messages('delayed:3', ackmode: 'reject_requeue_false') # simulate delayed message timeout
          sleep 0.1

          expect(delayed_queues).to eq(['delayed:3', 'delayed:30'])

          rabbitmq_messages('delayed:30', ackmode: 'reject_requeue_false') # simulate delayed message timeout
          sleep 0.1

          #TODO: override default max_retries to 2 to make this spec shorter
   
          expect(delayed_queues).to eq(['delayed:3', 'delayed:30', 'delayed:90'])

          rabbitmq_messages('delayed:90', ackmode: 'reject_requeue_false')
          sleep 0.1

          expect(delayed_queues).to contain_exactly('delayed:3', 'delayed:30', 'delayed:90', 'delayed:240')

          rabbitmq_messages('delayed:240', ackmode: 'reject_requeue_false')
          sleep 0.1

          expect_logs name: 'sneakers',
            to_include: [
              'Retries exhausted'
            ]

          expect(delayed_queues.sort).to contain_exactly('delayed:3', 'delayed:30', 'delayed:90', 'delayed:240')
        end
      end

      def delayed_queues
        rabbitmq_queues(columns: [:name]).select { |queue| queue.name.starts_with?('delayed:') }.map(&:name)
      end

      describe 'retried job headers' do
        subject do
          super()
          rabbitmq_messages('delayed:3').first.properties.headers
        end

        it 'have error details', :aggregate_failures do
          expect(subject['x-last-error-name']).to eq 'StandardError'
          expect(ActiveSupport::Gzip.decompress(Base64.decode64(subject['x-last-error-details']))).to include('Some error message')
        end
      end
    end
  end
end
