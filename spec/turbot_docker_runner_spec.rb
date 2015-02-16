require 'spec_helper'

describe TurbotDockerRunner do

  before(:each) do
    @params = {
      "bot_name"=>"miss-piggy",
      "run_id"=>"draft",
      "run_uid"=>"531",
      "run_type"=>"draft",
      "user_api_key"=>"d95542ef0af45a507af73798"
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

  it "clones the repo" do
    expect(Git).to receive(:clone).with("git@github.com:oa-bots/miss-piggy.git", '/tmp/data/repo/m/miss-piggy')
    @runner.synchronise_repo
  end

  it "Creates the docker container" do
    Git.clone("git@github.com:oa-bots/miss-piggy.git", '/tmp/data/repo/m/miss-piggy')
    container_params = {
      'name' => "miss-piggy_531",
      'Cmd' => ['/bin/bash', '-l', '-c', '/usr/bin/time -v -o /output/time.out ruby /utils/wrapper.rb'],
      'User' => 'scraper',
      'Image' => "opencorporates/morph-ruby",
      'Privileged' => true,
      'Memory' => 1.gigabyte,
      'Env' => ["RUN_TYPE=draft", "MORPH_URL=http://localhost"],
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