# frozen_string_literal: true

describe 'Consumers' do
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
