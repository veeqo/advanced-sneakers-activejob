# frozen_string_literal: true

describe 'Publishing', :rabbitmq do
  before { cleanup_logs }

  context 'when job has "routing_key" method defined' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        class JobWithRoutingKey < ApplicationJob
          queue_as :foobar

          def routing_key
            'custom_routing_key'
          end
        end

        JobWithRoutingKey.perform_later('whatever')
      end
    end

    it 'publishes message with custom routing key' do
      subject

      expect_logs name: 'sneakers',
                  to_include: 'to [custom_routing_key]',
                  to_exclude: 'to [foobar]'
    end
  end

  context 'when job has no routing key method defined' do
    context 'when safe_publish is on' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.safe_publish = true }
          CustomQueueJob.perform_later('this message wond be lost')
        end
      end

      it 'creates queue before publishing' do
        expect do
          subject
        end.to change { rabbitmq_queues(columns: [:name]) }.from([]).to([{ 'name' => 'custom' }])
      end

      it 'message is not lost' do
        subject
        message = rabbitmq_messages('custom').first

        expect(message['payload']).to include('this message wond be lost')
      end
    end

    context 'when safe_publish is off' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.safe_publish = false }
          CustomQueueJob.perform_later('I have configured RMQ routing in advance')
        end
      end

      it 'does not create queue before publishing' do
        expect do
          subject
        end.not_to change { rabbitmq_queues(columns: [:name]) }.from([])
      end
    end
  end
end
