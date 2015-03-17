require 'turbot_runner'
require 'iron_mq'

class Handler < TurbotRunner::BaseHandler
  attr_reader :ended

  def initialize(bot_name, config, run_id)
    @bot_name = bot_name
    @config = config
    @run_id = run_id
    @ended = false
  end

  def handle_valid_record(record, data_type)
    message = {
      :type => 'bot.record',
      :bot_name => @bot_name,
      :snapshot_id => @run_id,
      :data => record,
      :data_type => data_type,
      :identifying_fields => identifying_fields_for(data_type)
    }
    #Hutch.publish('bot.record', message)
    #queue.post(message.to_json)
  end

  def handle_run_ended
    message = {
      :type => 'run.ended',
      :snapshot_id => @run_id,
      :bot_name => @bot_name
    }
    #Hutch.publish('bot.record', message)
    #queue.post(message.to_json)
    @ended = true
  end

  def identifying_fields_for(data_type)
    if data_type == @config['data_type']
      @config['identifying_fields']
    else
      transformers = @config['transformers'].select {|transformer| transformer['data_type'] == data_type}
      raise "Expected to find precisely 1 matching transformer matching #{data_type} in #{@config}" unless transformers.size == 1
      transformers[0]['identifying_fields']
    end
  end

  def iron_mq
    #@@ironmq ||= IronMQ::Client.new(token: ENV['IRON_MQ_TOKEN'], project_id: ENV['IRON_MQ_PROJECT_ID'], host: 'mq-aws-eu-west-1.iron.io')
  end

  def queue
    #iron_mq.queue("turbot_addresses")
  end
end
