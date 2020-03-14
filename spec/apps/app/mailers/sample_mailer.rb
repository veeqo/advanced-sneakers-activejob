# frozen_string_literal: true

class SampleMailer < ApplicationMailer
  def greetings(name:)
    mail to: 'to@example.org',
         body: "Hello, #{name}",
         content_type: 'text/plain',
         subject: 'Sample email'
  end
end
