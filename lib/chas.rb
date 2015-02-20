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

  get '/' do
    redirect to 'https://camo.githubusercontent.com/961a4df8f9b282c1dc394e3462ef9dbde97b249e/687474703a2f2f6d656469612e66697265626f782e636f6d2f7069632f70323138365f73383031355f6d61696e2e6a7067', 301
  end

  post '/runs', check: :valid_key? do
    Resque.enqueue(TurbotDockerRunner, params)
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
