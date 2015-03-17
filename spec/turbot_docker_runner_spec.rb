require 'spec_helper'

describe TurbotDockerRunner do

  before(:each) do
    @params = {
      "bot_name"=>"miss-piggy",
      "run_id"=>"draft",
      "run_uid"=>"531",
      "run_type"=>"draft",
      "last_run_at" => "1970-01-01T00:00:00 +0000",
      "user_api_key"=>"d95542ef0af45a507af73798",
      "env" => {'FOO' => 'bar'}
    }
    @runner = TurbotDockerRunner.new(@params)
  end

  before(:each) do
    `rm -rf /tmp/data/`
  end

  it "sets up the correct paths" do
    expect(@runner.repo_path).to eq('/tmp/data/repo/m/miss-piggy')
    expect(@runner.data_path).to eq('/tmp/data/data/m/miss-piggy')
    expect(@runner.output_path).to eq('/tmp/data/output/draft/m/miss-piggy/531')
    expect(@runner.downloads_path).to eq('/tmp/data/downloads/m/miss-piggy/531/d95542ef0af45a507af73798')
  end

  it "has correct env" do
    expect(@runner.env['FOO']).to eq 'bar'
  end

  it "has a last-run-at" do
    expect(@runner.last_run_at).to eq '1970-01-01T00:00:00 +0000'
  end

  it "clones the repo" do
    expect(Git).to receive(:clone).with("https://github.com/oa-bots/miss-piggy", '/tmp/data/repo/m/miss-piggy')
    @runner.synchronise_repo
  end

  it "Creates the docker container" do
    Git.clone("git@github.com:oa-bots/miss-piggy.git", '/tmp/data/repo/m/miss-piggy')
    container_params = {
      'name' => "miss-piggy_531",
      'Cmd' => ['/bin/bash', '-l', '-c', '/usr/bin/time -v -o /output/time.out ruby /utils/wrapper.rb'],
      'User' => 'scraper',
      'Image' => "openaddresses/morph-ruby",
      'Privileged' => true,
      'Memory' => 1.gigabyte,
      'Env' => [
        "BOT_NAME=miss-piggy",
        "RUN_ID=531",
        "RUN_TYPE=draft",
        "MORPH_URL=http://localhost",
        "LAST_RUN_AT='1970-01-01T00:00:00 +0000'",
        "IRON_MQ_TOKEN=",
        "IRON_MQ_PROJECT_ID=",
        "FOO=bar"
        ]
    }
    expect(Docker::Container).to receive(:create).with(container_params, Docker::Connection)
    @runner.create_container
  end

  # it "runs the docker container" do
  #   Git.clone("git@github.com:oa-bots/miss-piggy.git", '/tmp/data/repo/m/miss-piggy')
  #   container = double('Docker::Container')
  #   expect(container).to receive(:start)
  #   expect(container).to receive(:wait)
  #   @runner.run_in_container
  # end

end
