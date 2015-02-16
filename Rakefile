require File.join(File.dirname(__FILE__), 'lib/chas.rb')
require 'resque/tasks'

Dir.glob('lib/tasks/*.rake').each { |r| import r }

unless ENV['RACK_ENV'] == 'production'
  require 'rspec/core/rake_task'
  require 'cucumber/rake/task'

  Cucumber::Rake::Task.new
  RSpec::Core::RakeTask.new

  task :default => [:cucumber, :spec]
end
