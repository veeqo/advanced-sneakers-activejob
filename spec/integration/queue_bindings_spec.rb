# frozen_string_literal: true

describe 'Queue bindings', :rabbitmq do
  context 'when job has "routing_key" method defined' do
    context 'when advanced_sneakers is configured to create binding with queue name' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.bind_by_queue_name = true }

          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            def routing_key
              'custom_routing_key'
            end
          end

          JobWithRoutingKey.perform_later('whatever')
        end
      end

      it 'are created for both queue name and binding key' do
        expect do
          subject
        end.to change { routing_keys_of_queue('foobar') }.from([]).to(%w[custom_routing_key foobar])
      end
    end

    context 'when advanced_sneakers is configured not to create binding with queue name' do
      subject do
        in_app_process(adapter: :advanced_sneakers) do
          AdvancedSneakersActiveJob.configure { |c| c.bind_by_queue_name = false }

          class JobWithRoutingKey < ApplicationJob
            queue_as :foobar

            def routing_key
              'custom_routing_key'
            end
          end

          JobWithRoutingKey.perform_later('whatever')
        end
      end

      it 'are created for binding key only' do
        expect do
          subject
        end.to change { routing_keys_of_queue('foobar') }.from([]).to(['custom_routing_key'])
      end
    end
  end

  context 'when job has no routing key method defined' do
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        class JobWithoutRoutingKey < ApplicationJob
          queue_as :foobar
        end

        JobWithoutRoutingKey.perform_later('whatever')
      end
    end

    it 'are created for queue name only' do
      expect do
        subject
      end.to change { routing_keys_of_queue('foobar') }.from([]).to(['foobar'])
    end
  end

  def routing_keys_of_queue(queue)
    rabbitmq_bindings(queue: queue).map { |b| b.fetch('routing_key') }.sort
  end
end
