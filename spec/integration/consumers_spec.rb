# frozen_string_literal: true

describe 'Consumers' do
  context 'when no ActiveJob prefix defined' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        class FooJob < ApplicationJob
          queue_as :baz
        end

        class BarJob < ApplicationJob
          queue_as :baz
        end

        class DynamicQueueJob < ApplicationJob
          queue_as do
            'dynamic'
          end
        end

        AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :only }

        Sneakers::Worker::Classes.call.map(&:name)
      end
    end

    it 'are defined per queue' do
      expect(subject.first).to match_array [
        'AdvancedSneakersActiveJob::DefaultQueueConsumer', # default consumer
        'AdvancedSneakersActiveJob::MailersQueueConsumer', # action mailer consumer
        'AdvancedSneakersActiveJob::CustomQueueConsumer', # see CustomQueueJob in spec/apps/app/jobs
        'AdvancedSneakersActiveJob::BazQueueConsumer', # baz queue consumer for FooJob and BarJob
        'AdvancedSneakersActiveJob::DynamicQueueConsumer' # dynamic queue consumer for DynamicQueueJob
      ]
    end
  end

  context 'when ActiveJob has prefix defined' do
    subject do
      in_app_process(adapter: :advanced_sneakers, env: { 'ACTIVE_JOB_QUEUE_NAME_PREFIX' => 'custom', 'ACTIVE_JOB_QUEUE_NAME_DELIMITER' => ':' }) do
        class FooJob < ApplicationJob
          queue_as :baz
        end

        class BarJob < ApplicationJob
          queue_as :baz
        end

        class DynamicQueueJob < ApplicationJob
          queue_as do
            'dynamic'
          end
        end

        AdvancedSneakersActiveJob.configure { |c| c.activejob_workers_strategy = :only }

        Sneakers::Worker::Classes.call.map(&:name)
      end
    end

    it 'are defined per queue with prefix ignored' do
      expect(subject.first).to match_array [
        'AdvancedSneakersActiveJob::DefaultQueueConsumer', # default consumer
        'AdvancedSneakersActiveJob::MailersQueueConsumer', # action mailer consumer
        'AdvancedSneakersActiveJob::CustomQueueConsumer', # see CustomQueueJob in spec/apps/app/jobs
        'AdvancedSneakersActiveJob::BazQueueConsumer', # baz queue consumer for FooJob and BarJob
        'AdvancedSneakersActiveJob::DynamicQueueConsumer' # dynamic queue consumer for DynamicQueueJob
      ]
    end
  end
end
