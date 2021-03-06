$:.unshift File.join( File.dirname(__FILE__) )

require 'json'
require 'docker'
require 'git'
require 'active_support/all'
require 'dotenv'
require 'logger'
require 'rest-client'

Dotenv.load

class TurbotDockerRunner
  attr_reader :last_run_at

  @queue = :turbot_docker_runs

  FileUtils.mkdir_p 'log'
  FileUtils.touch 'log/monitor.log'
  LOG = Logger.new('log/monitor.log')
  LOG.level = Logger::INFO

  def self.perform(params)
    runner = TurbotDockerRunner.new(params)
    runner.run
  end

  def env
    if @params['env'] && @params['env'] != ""
      @params['env']
    else
      {}
    end
  end

  def env_array
    env.map do |x|
      "#{x[0]}=#{x[1]}"
    end
  end

  def initialize(params)
    params = params.with_indifferent_access

    @params = params  # Keep hold of this for error reporting

    @bot_name = params[:bot_name]

    if params[:run_id] == 'draft'
      @run_id = 'draft'
    else
      @run_id = params[:run_id].to_i
    end

    @run_uid = params[:run_uid]
    @run_type = params[:run_type]
    @last_run_at = params[:last_run_at]
    @user_api_key = params[:user_api_key]

    @run_ended = false
  end

  def run
    set_up
    status_code = run_in_container

    symlink_output

    metrics = read_metrics

    if !config['incremental'] && !config['manually_end_run'] # the former is legacy
      @run_ended = true
    end

    report_run_ended(status_code, metrics)
  rescue Exception => e
    log_exception_and_notify_airbrake(e)

    report_run_ended(-1, {:class => e.class, :message => e.message, :backtrace => e.backtrace})
  ensure
    clean_up
  end

  def set_up
    set_up_directory(data_path)
    set_up_directory(output_path)
    set_up_directory(downloads_path)
    synchronise_repo

    clear_saved_vars if @run_type == 'first_of_scrape'

    @stdout_file = File.open(stdout_path, 'wb')
    @stdout_file.sync = true
    @stderr_file = File.open(stderr_path, 'wb')
    @stderr_file.sync = true
  end

  def clean_up
    @stdout_file.close if (@stdout_file && !@stdout_file.closed?)
    @stderr_file.close if (@stderr_file && !@stderr_file.closed?)
  end

###  def connect_to_rabbitmq
###    return if Hutch.connected?
###    LOG.info('Connecting to RabbitMQ')
###    Hutch.connect({}, HutchConfig)
###  end

  def set_up_directory(path)
    LOG.info("Setting up #{path}")
    FileUtils.mkdir_p(path)
    FileUtils.chmod(0777, path)
  end

  def synchronise_repo
    tries = 3

    FileUtils.rm_rf repo_path
    begin
      LOG.info("Cloning #{git_url} into #{repo_path}")
      Git.clone(git_url, repo_path)
    rescue Git::GitExecuteError
      LOG.info('Hit GitExecuteError')
      retry unless (tries -= 1).zero?
    end

    FileUtils.mkdir_p repo_path
    FileUtils.chmod 0777, repo_path
    File.symlink(data_path, File.join(repo_path, 'db'))
  end

  def clear_saved_vars
    FileUtils.rm_f(File.join(data_path, '_vars.yml'))
  end

  def run_in_container
    container = create_container

    begin
      local_root_path = Dir.pwd
      binds = [
        "#{repo_path}:/repo:ro",
        "#{data_path}:/data",
        "#{local_root_path}/utils:/utils:ro",
        "#{output_path}:/output"
      ]

      LOG.info("Starting container with bindings: #{binds}")
      container.start('Binds' => binds)

      container.attach do |stream, chunk|
        case stream
        when :stdout
          @stdout_file.write(chunk)
        when :stderr
          @stderr_file.write(chunk)
        end
      end

    rescue Exception => e
      log_exception_and_notify_airbrake(e)
      begin
        container.kill
      rescue Excon::Errors::SocketError => e
        LOG.info("Could not kill container")
      end
    ensure
      LOG.info('Waiting for container to finish')
      response = container.wait
      status_code = response['StatusCode']
      LOG.info('Deleting container')
      container.delete
    end

    LOG.info("Returning with status_code #{status_code}")
    status_code
  end

  def create_container
    LOG.info('Creating container')
    conn = Docker::Connection.new(docker_url, read_timeout: 24.hours)
    container_params = {
      'name' => "#{@bot_name}_#{@run_uid}",
      'Cmd' => ['/bin/bash', '-l', '-c', command],
      'User' => 'scraper',
      'Image' => image,
      'Privileged' => true,
      # We have 8GB to divide between 10 processes, but there's scope for
      # swapping and most processes won't need that much memory.
      'Memory' => 1.gigabyte,
      # MORPH_URL is used by Turbotlib to determine whether a scraper is
      # running in production.
      'Env' => [
        "BOT_NAME=#{@bot_name}",
        "RUN_ID=#{@run_uid}",
        "RUN_TYPE=#{@run_type}",
        "MORPH_URL=#{ENV['MORPH_URL']}",
        "LAST_RUN_AT='#{@last_run_at}'",
        "IRON_MQ_TOKEN=#{ENV['IRON_MQ_TOKEN']}",
        "IRON_MQ_PROJECT_ID=#{ENV['IRON_MQ_PROJECT_ID']}"
      ].concat(env_array)
    }
    LOG.info("Creating container with params #{container_params}")
    Docker::Container.create(container_params, conn)
  end

  def symlink_output
    File.symlink(
    File.join(output_path, 'scraper.out'),
    File.join(downloads_path, "#{@bot_name}-#{@run_uid}.out")
    )
  end

  def docker_url
    ENV["DOCKER_URL"] || Docker.default_socket_url
  end

  def local_root_path
    Rails.root
  end

  def command
    '/usr/bin/time -v -o /output/time.out ruby /utils/wrapper.rb'
  end

  def image
    {
      "python" => "opencorporates/morph-python",
      "ruby" => "openaddresses/morph-ruby",
    }[language]
  end

  def language
    if File.exist?(File.join(repo_path, 'scraper.rb'))
      'ruby'
    elsif File.exist?(File.join(repo_path, 'scraper.py'))
      'python'
    else
      raise "Could not find scraper at #{repo_path}"
    end
  end

###  def send_run_ended_to_angler
###    message = {
###      :type => 'run.ended',
###      :bot_name => @bot_name,
###      :snapshot_id => @run_id
###    }
###    Hutch.publish('bot.record', message)
###  end

  def read_metrics
    metrics = {}

    begin
      File.readlines(File.join(output_path, 'time.out')).each do |line|
        field, value = parse_metric_line(line)
        metrics[field] = value if value
      end
    rescue Errno::ENOENT
      # sometimes time.out doesn't get produced
    end

    # There's a bug in GNU time 1.7 which wrongly reports the maximum resident
    # set size on the version of Ubuntu that we're using.
    # See https://groups.google.com/forum/#!topic/gnu.utils.help/u1MOsHL4bhg
    unless metrics.empty?
      raise "Page size not known" unless metrics[:page_size]
      metrics[:maxrss] = metrics[:maxrss] * 1024 / metrics[:page_size]
    end

    num_records = 0

    begin
      # http://stackoverflow.com/questions/2650517/count-the-number-of-lines-in-a-file-without-reading-entire-file-into-memory
      filename = File.join(output_path, 'scraper.out')
      num_records = %x{wc -l #{filename}}.to_i
    rescue Errno::ENOENT
    end

    metrics[:num_records] = num_records

    metrics
  end

  def parse_metric_line(line)
    field, value = line.split(": ")

    case field
    when /Maximum resident set size \(kbytes\)/
      [:maxrss, value.to_i]
    when /Minor \(reclaiming a frame\) page faults/
      [:minflt, value.to_i]
    when /Major \(requiring I\/O\) page faults/
      [:majflt, value.to_i]
    when /User time \(seconds\)/
      [:utime, value.to_f]
    when /System time \(seconds\)/
      [:stime, value.to_f]
    when /Elapsed \(wall clock\) time \(h:mm:ss or m:ss\)/
      n = value.split(":").map{|v| v.to_f}
      if n.count == 2
        m, s = n
        h = 0
      elsif n.count == 3
        h, m, s = n
      end
      [:wall_time, (h * 60 + m) * 60 + s ]
    when /File system inputs/
      [:inblock, value.to_i]
    when /File system outputs/
      [:oublock, value.to_i]
    when /Voluntary context switches/
      [:nvcsw, value.to_i]
    when /Involuntary context switches/
      [:nivcsw, value.to_i]
    when /Page size \(bytes\)/
      [:page_size, value.to_i]
    end
  end

  def report_run_ended(status_code, metrics)
    # TODO find the right place to put this
    host = ENV['TURBOT_HOST'] || 'http://turbot'
    url = "#{host}/api/runs/#{@run_uid}"

    params = {
      :api_key => ENV['TURBOT_API_KEY'],
      :status_code => status_code,
      :metrics => metrics,
      :run_ended => @run_ended
    }

    LOG.info("Reporting run ended to #{url}")
    RestClient.put(url, params.to_json, :content_type => 'application/json')
  end

  def config
    @config ||= JSON.parse(File.read(File.join(repo_path, 'manifest.json')))
  end

  def repo_path
    File.join(
    base_path,
    'repo',
    @bot_name[0],
    @bot_name
    )
  end

  def data_path
    File.join(
    base_path,
    'data',
    @bot_name[0],
    @bot_name
    )
  end

  def output_path
    File.join(
    base_path,
    'output',
    @run_id == 'draft' ? 'draft' : 'non-draft',
    @bot_name[0],
    @bot_name,
    @run_uid.to_s
    )
  end

  def downloads_path
    File.join(
    base_path,
    'downloads',
    @bot_name[0],
    @bot_name,
    @run_uid.to_s,
    @user_api_key
    )
  end

  def stdout_path
    File.join(output_path, 'stdout')
  end

  def stderr_path
    File.join(output_path, 'stderr')
  end

  def git_url
    "https://#{ENV['GITHOST_DOMAIN']}/#{ENV['GITHOST_GROUP']}/#{@bot_name}"
  end

  def base_path
    if ENV['RACK_ENV'] == "test"
      '/tmp/data/'
    else
      ENV['CHAS_BASE_PATH']
    end
  end

  def log_exception_and_notify_airbrake(e)
    LOG.error("Hit error when running container: #{e}")
    #e.backtrace.each { |line| LOG.error(line) }
    #    Airbrake.notify(e, :parameters => @params)
  end

end
