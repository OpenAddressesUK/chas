$:.unshift File.join( File.dirname(__FILE__) )

require 'sinatra/base'
require 'resque'
require 'turbot_docker_runner'
require 'dotenv'

Dotenv.load

class Chas < Sinatra::Base
  register do
    def check(name)
      condition do
        error 401 unless send(name) == true
      end
    end
  end

  helpers do
    def valid_key?
      @token = params['user_api_key']
      ENV['CHAS_ALLOWED_KEYS'].split(",").include?(@token)
    end
  end

  post '/runs', check: :valid_key? do
    Resque.enqueue(TurbotDockerRunner, params)
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
