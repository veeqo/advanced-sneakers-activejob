# frozen_string_literal: true

class SampleConsumer
  include Sneakers::Worker
  from_queue 'sneakers_queue'

  def work(msg)
    Rails.logger.info("Performing '#{msg}'")
    raise if msg.include?('fail')

    ack!
  end
end
