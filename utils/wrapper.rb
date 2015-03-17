require 'turbot_runner'
require 'iron_mq'

# Flush output immediately
STDOUT.sync = true
STDERR.sync = true

MAX_DRAFT_ROWS = 2000

class Handler < TurbotRunner::BaseHandler
  def initialize
    super
    @count = 0
  end

  def handle_valid_record(record, data_type)
    if data_type == 'primary data'
      if ENV['RUN_TYPE'] == "draft"
        raise TurbotRunner::InterruptRun if @count > MAX_DRAFT_ROWS
      else
        queue.post(message.to_json)
      end
      @count += 1
      STDOUT.puts "#{Time.now} :: Handled #{@count} records" if @count % 1000 == 0
    end
  end

  def handle_invalid_record(record, data_type, error_message)
    STDERR.puts
    STDERR.puts "The following record is invalid:"
    STDERR.puts record.to_json
    STDERR.puts " * #{error_message}"
    STDERR.puts
  end

  def handle_invalid_json(line)
    STDERR.puts
    STDERR.puts "The following line is invalid JSON:"
    STDERR.puts line
  end
  
  def iron_mq
    @@ironmq ||= IronMQ::Client.new(token: ENV['IRON_MQ_TOKEN'], project_id: ENV['IRON_MQ_PROJECT_ID'], host: 'mq-aws-eu-west-1.iron.io')
  end

  def queue
    iron_mq.queue("turbot_test")
  end

end

runner = TurbotRunner::Runner.new(
  '/repo',
  :log_to_file => true,
  :record_handler => Handler.new,
  :output_directory => '/output'
)

rc = runner.run
exit(rc)
 
