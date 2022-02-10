# frozen_string_literal: true

require 'timeout'

module LogHelpers
  def expect_logs(name:, to_include: nil, to_exclude: nil, filters: %i[job_id created_at], wait: 5)
    to_include = Array(to_include).compact
    to_exclude = Array(to_exclude).compact
    file = File.open(logs_path.join("#{name}.log"))

    Timeout.timeout(wait) do
      loop do
        @text = filter_logs(text: file.tap(&:rewind).read, filters: filters)

        break if to_include.all? { |line| @text.public_send(line_boolean_matcher(line), line) } &&
                 to_exclude.none? { |line| @text.public_send(line_boolean_matcher(line), line) }

        sleep(0.05)
      end
    end
  rescue Timeout::Error
    aggregate_failures do
      to_include.each { |line| expect(@text).to public_send(line_matcher(line), line) }
      to_exclude.each { |line| expect(@text).not_to public_send(line_matcher(line), line) }
    end
  ensure
    file.close
  end

  def cleanup_logs
    Dir[logs_path.join('*.log')].each { |log| FileUtils.rm(log) }
  end

  private

  def line_matcher(line)
    case line
    when String then :include
    when Regexp then :match
    else
      raise ArgumentError, "unsupported class of 'line' argument: #{line.class}"
    end
  end

  def line_boolean_matcher(line)
    [
      line_matcher(line).to_s,
      '?'
    ].join.to_sym
  end

  def logs_path
    Pathname.new(File.expand_path('../apps/log', __dir__))
  end

  def filter_logs(text:, filters:)
    filtered_text = text

    {
      job_id: /\(Job ID[^)]+\) /,
      created_at: /enqueued at [^ ]+ /
    }.each do |filter, regex|
      filtered_text.gsub!(regex, '') if filters.include?(filter)
    end

    filtered_text
  end
end

RSpec.configure do |config|
  config.include LogHelpers
end
