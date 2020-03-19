# frozen_string_literal: true

module AdvancedSneakersActiveJob
  # Handler puts error details to message header and reenqueues job with delay
  class Handler < Sneakers::Handlers::Oneshot
    def error(delivery_info, properties, message, error)
      params = properties.to_h
      params[:headers] = patch_headers(params[:headers], delivery_info, error)
      params[:routing_key] = delivery_info.routing_key
      params[:delay] = calculate_delay(params[:headers], delivery_info)

      AdvancedSneakersActiveJob.publisher.publish_delayed(message, params)

      acknowledge(delivery_info, properties, message)
    end

    private

    def patch_headers(headers, delivery_info, error)
      queue = queue_name(delivery_info)
      exchange = delivery_info.exchange
      routing_key = delivery_info.routing_key

      track_error_in_headers(headers, error)
      track_death_in_headers(headers, queue, exchange, routing_key)

      headers
    end

    # Headers are patched to mimic behavior of "nack" and DLX
    def track_death_in_headers(headers, queue, exchange, routing_key)
      headers['x-first-death-exchange'] ||= exchange
      headers['x-first-death-queue'] ||= queue
      headers['x-first-death-reason'] ||= 'rejected'
      headers['x-death'] ||= []

      if (death = death_header(headers, queue))
        death['count'] += 1
      else
        headers['x-death'] << build_death_row(queue, exchange, routing_key)
      end
    end

    def build_death_row(queue, exchange, routing_key)
      {
        'count' => 1,
        'reason' => 'rejected',
        'queue' => queue,
        'time' => Time.now,
        'exchange' => exchange,
        'routing-keys' => [routing_key]
      }
    end

    def track_error_in_headers(headers, error)
      details = if error.respond_to?(:full_message) # ruby 2.5+
                  error.full_message
                else
                  ([error.message] + error.backtrace).join("\n")
                end

      headers['x-last-error-name'] = error.class.name
      headers['x-last-error-details'] = Base64.encode64(ActiveSupport::Gzip.compress(details))
    end

    def calculate_delay(headers, delivery_info)
      death_count = death_header(headers, queue_name(delivery_info)).fetch('count')

      AdvancedSneakersActiveJob.config.retry_delay_proc.call(death_count)
    end

    def queue_name(delivery_info)
      delivery_info.consumer.queue.name
    end

    def death_header(headers, queue_name)
      headers.fetch('x-death').detect { |death| death.fetch('queue') == queue_name }
    end
  end
end
