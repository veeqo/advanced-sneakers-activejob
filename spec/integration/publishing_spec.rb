# frozen_string_literal: true

describe 'Publishing', :rabbitmq do
  before { cleanup_logs }

  context 'when job has no message options configured' do
    context 'when handle_unrouted_messages is on' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = true }
          CustomQueueJob.perform_later("I don't want this message to be lost")
        end
      end

      it 'creates proper queue' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]) }.from([]).to([{ 'name' => 'custom' }])
      end

      it 'message is not lost' do
        subject
        message = rabbitmq_messages('custom').first

        expect(message['payload']).to include("I don't want this message to be lost")
      end
    end

    context 'when handle_unrouted_messages is off' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = false }
          CustomQueueJob.perform_later("I don't care if message would be lost")
        end
      end

      it 'does not create queue' do
        expect do
          subject
        end.not_to change { rabbitmq_queues(columns: [:name]) }.from([])
      end

      it 'warns about lost message' do
        subject

        expect_logs name: 'rails',
                    to_include: 'WARN -- : Message is not routed!'
      end
    end
  end

  context 'when job has message options configured' do
    context 'when static routing key is set' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            message_options routing_key: 'custom_routing_key'
          end

          JobWithRoutingKey.perform_later('whatever')
        end
      end

      it 'publishes message with custom routing key' do
        subject

        expect_logs name: 'rails',
                    to_include: 'with routing_key [custom_routing_key]',
                    to_exclude: 'with routing_key [foobar]'
      end
    end

    context 'when routing key is set to nil' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            message_options routing_key: nil
          end

          JobWithRoutingKey.perform_later('whatever')
        end
      end

      it 'publishes message with custom routing key' do
        subject

        expect_logs name: 'rails',
                    to_include: 'with routing_key []',
                    to_exclude: 'with routing_key [foobar]'
      end
    end

    context 'when routing key proc given' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            message_options routing_key: ->(job) { ['user', job.arguments.first[:user_id]].join('.') }
          end

          JobWithRoutingKey.perform_later(user_id: 'hl3', message: 'Good morning, Mr. Freeman')
        end
      end

      it 'publishes message with custom routing key' do
        subject

        expect_logs name: 'rails',
                    to_include: 'with routing_key [user.hl3]',
                    to_exclude: 'with routing_key [foobar]'
      end
    end

    context 'when other message options are given' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            message_options headers: { 'foo' => 'bar' }
          end

          JobWithRoutingKey.perform_later('whatever')
        end
      end

      it 'publishes message with routing key equal to queue name' do
        subject

        expect_logs name: 'rails',
                    to_include: 'with routing_key [foobar]'
      end

      it 'respects custom message options' do
        subject

        expect(rabbitmq_messages('foobar').first.properties.headers).to eq('foo' => 'bar')
      end
    end
  end

  context 'when job is delayed to a past date' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        CustomQueueJob.set(wait_until: 1.day.ago).perform_later('back to the future')
      end
    end

    let(:message) { rabbitmq_messages('custom').first }

    it 'is routed to queue for consumer' do
      subject

      expect(message['payload']).to include('back to the future')
    end
  end

  context 'when job is delayed to a future' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        CustomQueueJob.set(wait: 5.minutes).perform_later('this will happen in 5 minutes')
        CustomQueueJob.set(wait: 10.minutes).perform_later('this will happen in 10 minutes')
      end
    end

    let(:expected_queues) do
      [
        {
          'arguments' => {
            'x-dead-letter-exchange' => 'activejob',
            'x-message-ttl' => 300_000, # 5 minute
            'x-queue-mode' => 'lazy'
          },
          'auto_delete' => false,
          'durable' => true,
          'exclusive' => false,
          'name' => 'delayed:300'
        },
        {
          'arguments' => {
            'x-dead-letter-exchange' => 'activejob',
            'x-message-ttl' => 600_000, # 10 minutes
            'x-queue-mode' => 'lazy'
          },
          'auto_delete' => false,
          'durable' => true,
          'exclusive' => false,
          'name' => 'delayed:600'
        }
      ]
    end

    it 'is routed to queue with proper TTL and DLX' do
      subject

      aggregate_failures do
        expect(rabbitmq_queues).to eq expected_queues
        expect(rabbitmq_messages('delayed:300').first['payload']).to include('this will happen in 5 minutes')
        expect(rabbitmq_messages('delayed:600').first['payload']).to include('this will happen in 10 minutes')
      end
    end
  end
end
