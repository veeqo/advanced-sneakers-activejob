# frozen_string_literal: true

module AdvancedSneakersActiveJob
  CONTENT_TYPE = 'application/vnd.activejob+json'
end

Sneakers::ContentType.register(
  content_type: AdvancedSneakersActiveJob::CONTENT_TYPE,
  deserializer: ->(payload) { ActiveSupport::JSON.decode(payload) },
  serializer: ->(payload) { ActiveSupport::JSON.encode(payload) }
)
