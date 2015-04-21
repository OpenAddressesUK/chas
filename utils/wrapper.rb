require 'turbot_runner'
require 'iron_mq'
require_relative 'handler'

# Flush output immediately
STDOUT.sync = true
STDERR.sync = true

MAX_DRAFT_ROWS = 200

runner = TurbotRunner::Runner.new(
  '/repo',
  :log_to_file => true,
  :record_handler => Handler.new(ENV['BOT_NAME'], ENV['RUN_ID']),
  :output_directory => '/output'
)

rc = runner.run
exit(rc)
