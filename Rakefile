require File.join(File.dirname(__FILE__), 'lib/chas.rb')
import File.join(File.dirname(__FILE__), 'lib/tasks/docker.rake')

unless ENV['RACK_ENV'] == 'production'
  require 'rspec/core/rake_task'
  require 'cucumber/rake/task'

  Cucumber::Rake::Task.new
  RSpec::Core::RakeTask.new

  task :default => [:cucumber, :spec]
end
