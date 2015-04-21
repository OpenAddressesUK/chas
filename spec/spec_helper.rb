$:.unshift File.join( File.dirname(__FILE__), "lib")

require 'coveralls'
Coveralls.wear!

require 'rspec'
require 'webmock/rspec'
require 'turbot_docker_runner'

ENV['RACK_ENV'] = 'test'

RSpec.configure do |config|
  config.order = "random"
end
