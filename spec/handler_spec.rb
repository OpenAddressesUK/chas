require 'spec_helper'
require_relative '../utils/handler'

ENV['IRON_MQ_TOKEN']='t0ken'
ENV['IRON_MQ_PROJECT_ID'] = '012345678901234567890123'
STDOUT.sync = true
STDERR.sync = true

describe Handler do
  it 'retries if Iron MQ is a bastard' do
    stub_request(:post, /.*/).to_return(status: 500).times(5).
    then.to_return(status: 200)
    h = Handler.new 'bert', '99'
    allow(h).to receive(:sleep) { nil}

    expect { h.post_to_iron_mq({foo: 'bar'} ) }.to output(/Hit error, trying again in 5 seconds\nHit error, trying again in 10 seconds/).to_stderr
  end
end
