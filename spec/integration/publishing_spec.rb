# frozen_string_literal: true

describe 'Publishing', :rabbitmq do
  before { cleanup_logs }

  context 'when job has no message options configured' do
    context 'when handle_unrouted_messages is on' do
      context 'when publishing job without message options set' do
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

      context 'when publishing job with message options set' do
        subject do
          in_app_process(adapter: :advanced_sneakers) do
            AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = true }
            CustomQueueJob.set(queue: 'foo', message_id: '123', priority: 1, headers: { 'baz' => 'qux' }).perform_later('quux')
          end
        end

        it 'creates proper queue' do
          expect do
            subject
          end.to change { rabbitmq_queues(columns: [:name]) }.from([]).to([{ 'name' => 'foo' }])
        end

        it 'message is not lost and has all custom options' do
          subject
          message = rabbitmq_messages('foo').first

          expect(message.properties.message_id).to eq('123')
          expect(message.properties.priority).to eq(1)
          expect(message.properties.headers).to eq({ 'baz' => 'qux' })
          expect(message.payload).to include('quux')
        end
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

            message_options priority: 2, headers: { 'foo' => 'bar' }
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

        message = rabbitmq_messages('foobar').first

        expect(message.properties.priority).to eq(2)
        expect(message.properties.headers).to eq('foo' => 'bar')
      end
    end

    context 'when publishing job with message options set' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            message_options priority: 2, headers: { 'foo' => 'bar' }
          end

          JobWithRoutingKey.set(priority: 1, headers: { 'baz' => 'qux' }).perform_later('whatever')
        end
      end

      it 'merges class-level message_options with ad-hoc options' do
        subject

        message = rabbitmq_messages('foobar').first

        expect(message.properties.priority).to eq(1)
        expect(message.properties.headers).to eq('foo' => 'bar', 'baz' => 'qux')
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
    context 'when ActiveJob has no queue name prefix configured' do
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

    context 'when ActiveJob has queue name prefix configured' do
      subject do
        in_app_process(adapter: :advanced_sneakers, env: { 'ACTIVE_JOB_QUEUE_NAME_PREFIX' => 'custom', 'ACTIVE_JOB_QUEUE_NAME_DELIMITER' => '~' }) do
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
            'name' => 'custom~delayed:300'
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
            'name' => 'custom~delayed:600'
          }
        ]
      end

      it 'is routed to queue with proper TTL and DLX' do
        subject

        aggregate_failures do
          expect(rabbitmq_queues).to eq expected_queues
          expect(rabbitmq_messages('custom~delayed:300').first['payload']).to include('this will happen in 5 minutes')
          expect(rabbitmq_messages('custom~delayed:600').first['payload']).to include('this will happen in 10 minutes')
        end
      end
    end

    context 'when ActiveJob has queue name prefix configured' do
      subject do
        in_app_process(adapter: :advanced_sneakers, env: { 'ACTIVE_JOB_QUEUE_NAME_PREFIX' => 'custom', 'ACTIVE_JOB_QUEUE_NAME_DELIMITER' => '~' }) do
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
            'name' => 'custom~delayed:300'
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
            'name' => 'custom~delayed:600'
          }
        ]
      end

      it 'is routed to queue with proper TTL and DLX' do
        subject

        aggregate_failures do
          expect(rabbitmq_queues).to eq expected_queues
          expect(rabbitmq_messages('custom~delayed:300').first['payload']).to include('this will happen in 5 minutes')
          expect(rabbitmq_messages('custom~delayed:600').first['payload']).to include('this will happen in 10 minutes')
        end
      end
    end
  end

  context 'when ActiveJob has queue name prefix configured' do
    subject do
      in_app_process(adapter: :advanced_sneakers, env: { 'ACTIVE_JOB_QUEUE_NAME_PREFIX' => 'awesome', 'ACTIVE_JOB_QUEUE_NAME_DELIMITER' => ':' }) do
        AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = true }
        ApplicationJob.perform_later('Application job')
        CustomQueueJob.perform_later('Custom queue job')
      end
    end

    if ActiveJob.gem_version >= Gem::Version.new('6.0') # https://github.com/rails/rails/pull/34376
      it 'creates proper queues' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]).map(&:name).sort }.from([]).to(['awesome:custom', 'awesome:default'])
      end

      it 'messages are not lost' do
        subject

        expect(rabbitmq_messages('awesome:default').first['payload']).to include('Application job')
        expect(rabbitmq_messages('awesome:custom').first['payload']).to include('Custom queue job')
      end
    else
      it 'creates proper queues' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]).map(&:name).sort }.from([]).to(['awesome:custom', 'default'])
      end

      it 'messages are not lost' do
        subject

        expect(rabbitmq_messages('default').first['payload']).to include('Application job')
        expect(rabbitmq_messages('awesome:custom').first['payload']).to include('Custom queue job')
      end
    end
  end

  if ActiveJob.gem_version >= Gem::Version.new('5.0')
    context 'when there are ActiveJob classes with custom queue adapter' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = true }

          class FooJob < ApplicationJob
            self.queue_adapter = :async

            queue_as :bar
          end

          FooJob.perform_later('Foo job')
          CustomQueueJob.perform_later('Custom queue job')
        end
      end

      it 'creates queues for jobs with matching adapter' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]).map(&:name).sort }.from([]).to(['custom']) # no "bar"
      end
    end

    context 'when advanced_sneakers is set as custom adapter' do
      subject do
        in_app_process(adapter: :inline) do
          AdvancedSneakersActiveJob.configure { |c| c.handle_unrouted_messages = true }

          class FooJob < ApplicationJob
            self.queue_adapter = :advanced_sneakers

            queue_as :bar
          end

          FooJob.perform_later('Foo job')
          CustomQueueJob.perform_later('Custom queue job')
        end
      end

      it 'creates queues for jobs with matching adapter' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]).map(&:name).sort }.from([]).to(['bar']) # no "custom"
      end
    end
  end
end
