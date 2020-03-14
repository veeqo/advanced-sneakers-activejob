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
    subject do
      in_app_process(adapter: :advanced_sneakers) do
        class JobWithoutRoutingKey < ApplicationJob
          queue_as :foobar
        end

        JobWithoutRoutingKey.perform_later('whatever')
      end
    end

    it 'publishes message with routing key equal to queue name' do
      subject

      expect_logs name: 'sneakers',
                  to_include: 'to [foobar]'
    end
  end
end
