# frozen_string_literal: true

# Runs separate ruby process and sends code snippet to it.
# Expects app to evaluate the code and return marshalized result in STDOUT. Logs are expected to be written to STDERR
module ChildProcessHelpers
  def in_app_process(adapter:, env: {}, &block)
    input_reader, input_writer = IO.pipe
    output_reader, output_writer = IO.pipe
    err_reader, err_writer = IO.pipe
    env = env.merge('RABBITMQ_URL' => ENV.fetch('RABBITMQ_URL'))

    pid = run_app_process(adapter: adapter, read: input_reader, write: output_writer, err: err_writer, env: env)

    input_writer.write source_code(block) # Sending code block to separate process
    input_writer.close # At this point child process starts to evaluate input
    input_reader.close

    Process.wait(pid)

    # At this point child process is expected to exit
    output_writer.close
    err_writer.close

    result = begin
      data = output_reader.read

      data.empty? ? data : load_response(data)
    end

    errors = err_reader.read

    output_reader.close
    err_reader.close

    [result, errors]
  end

  def load_response(data)
    Marshal.load(data)
  rescue TypeError
    # somebody writes to STDOUT? puts?
    data
  rescue ArgumentError, NameError
    'Can not be unmarshalized' # Current process might not know classes of child process
  end

  def run_app_process(adapter:, read:, write:, err:, env:)
    name = ['with', adapter, 'adapter'].join('_')
    app_path = Pathname.new(File.expand_path('../apps', __dir__)).join(name)
    Process.spawn(env, "ruby -r #{app_path}.rb -e 'Marshal.dump(eval(STDIN.read), STDOUT)'", in: read, out: write, err: err)
  end

  def start_sneakers_consumers(**args)
    in_app_process(**args) do
      require 'rake'
      require 'sneakers/tasks'
      Rake::Task['sneakers:run'].invoke
    end
  end

  def stop_sneakers_consumers
    return unless File.exist?('sneakers.pid')

    kill_process(File.open('sneakers.pid').read.to_i)
  ensure
    FileUtils.rm_rf('sneakers.pid')
  end

  def kill_process(pid)
    Process.kill('TERM', pid)

    begin
      Timeout.timeout(5) do
        sleep 0.1 until `pgrep -P #{pid}`.blank? # all processes of Sneakers are stopped
      end
    rescue Timeout::Error
      `pgrep -P #{pid}`.lines.each { |child_pid| Process.kill('KILL', child_pid.to_i) }
    end
  rescue Errno::ESRCH
    # No such process
  end

  def source_code(block)
    code = block.source.strip

    [
      /\sdo\s(.*)end\Z/m,
      /\{(.*)}\Z/m
    ].each do |regex|
      match = code[regex, 1]
      return match unless match.nil?
    end

    raise "Unsupported block:\n#{code}"
  end
end

RSpec.configure do |config|
  config.include ChildProcessHelpers
  config.after(:each) do
    stop_sneakers_consumers # ensure consumers stopped even if tests are failing
  end
end
