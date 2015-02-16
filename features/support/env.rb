ENV['RACK_ENV'] = 'test'

require File.join(File.dirname(__FILE__), '..', '..', 'lib/chas.rb')

require 'capybara'
require 'capybara/cucumber'
require 'cucumber/api_steps'
require 'rspec'
require 'cucumber/rspec/doubles'

Capybara.app = Chas

class ChasWorld
  include Capybara::DSL
  include RSpec::Expectations
  include RSpec::Matchers

  def app
    Chas
  end
end

World do
  ChasWorld.new
end
