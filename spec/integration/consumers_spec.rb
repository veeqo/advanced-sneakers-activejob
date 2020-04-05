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

        Sneakers::Worker::Classes.call.map { |consumer| [consumer.name, consumer.queue_name] }.to_h
      end
    end

    it 'are defined per queue' do
      expected_consumers = {
        'AdvancedSneakersActiveJob::DefaultConsumer' => 'default', # default consumer
        'AdvancedSneakersActiveJob::MailersConsumer' => 'mailers', # action mailer consumer
        'AdvancedSneakersActiveJob::CustomConsumer' => 'custom', # see CustomQueueJob in spec/apps/app/jobs
        'AdvancedSneakersActiveJob::BazConsumer' => 'baz', # baz queue consumer for FooJob and BarJob
        'AdvancedSneakersActiveJob::DynamicConsumer' => 'dynamic' # dynamic queue consumer for DynamicQueueJob
      }

      expect(subject.first).to eq(expected_consumers)
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

        Sneakers::Worker::Classes.call.map { |consumer| [consumer.name, consumer.queue_name] }.to_h
      end
    end

    it 'are defined per queue with prefix ignored in consumer class name' do
      expected_consumers = {
        'AdvancedSneakersActiveJob::CustomDefaultConsumer' => 'custom:default', # default consumer
        'AdvancedSneakersActiveJob::CustomMailersConsumer' => 'custom:mailers', # action mailer consumer
        'AdvancedSneakersActiveJob::CustomCustomConsumer' => 'custom:custom', # see CustomQueueJob in spec/apps/app/jobs
        'AdvancedSneakersActiveJob::CustomBazConsumer' => 'custom:baz', # baz queue consumer for FooJob and BarJob
        'AdvancedSneakersActiveJob::CustomDynamicConsumer' => 'custom:dynamic' # dynamic queue consumer for DynamicQueueJob
      }

      expect(subject.first).to eq(expected_consumers)
    end
  end
end
