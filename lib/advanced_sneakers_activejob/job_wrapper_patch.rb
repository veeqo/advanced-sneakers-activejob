module AdvancedSneakersActiveJob
  module JobWrapperPatch
    def work(msg)
      # In Rails 7, decode was lenient. In Rails 8, it strictly requires a String.
      # This handles both cases: if Sneakers already parsed it into a Hash, use it.
      job_data = msg.is_a?(String) ? ActiveSupport::JSON.decode(msg) : msg

      ActiveJob::Base.execute(job_data)
      ack!
    end
  end
end
