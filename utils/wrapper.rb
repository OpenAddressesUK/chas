require 'turbot_runner'
require 'iron_mq'

# Flush output immediately
STDOUT.sync = true
STDERR.sync = true

MAX_DRAFT_ROWS = 200

class Handler < TurbotRunner::BaseHandler
  def initialize(bot_name, run_id)
    super()
    @bot_name = bot_name
    @run_id = run_id
    @ended = false
    @count = 0
  end

  def handle_valid_record(record, data_type)
    if data_type == 'primary data'
      if ENV['RUN_TYPE'] == "draft"
        raise TurbotRunner::InterruptRun if @count > MAX_DRAFT_ROWS
      else
        message = {
          :type => 'bot.record',
          :bot_name => @bot_name,
          :snapshot_id => @run_id,
          :data => record,
          :data_type => 'address',
          :identifying_fields => identifying_fields_for('address')
        }
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
  
  def handle_run_ended
    message = {
      :type => 'run.ended',
      :snapshot_id => @run_id,
      :bot_name => @bot_name
    }
    queue.post(message.to_json)
    @ended = true
  end
  
  def identifying_fields_for(data_type)
    nil
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
  :record_handler => Handler.new(ENV['BOT_NAME'], ENV['RUN_ID']),
  :output_directory => '/output'
)

rc = runner.run
exit(rc)
 
