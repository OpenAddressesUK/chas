Given(/^I want to queue a scraper$/) do
  @params = {
    "bot_name"=>"miss-piggy",
    "run_id"=>"draft",
    "run_uid"=>"531",
    "run_type"=>"draft",
    "user_api_key"=>"d95542ef0af45a507af73798"
  }
end

When(/^I trigger a run$/) do
  post "/runs", @params
end

Then(/^the TurbotDockerRunnner job should be queued$/) do
  expect(Resque).to receive(:enqueue).with(TurbotDockerRunner, @params)
end

Given(/^I specify an incorrect API key$/) do
  @params["user_api_key"] = "thisisblatantlywrong"
end

Then(/^the TurbotDockerRunnner job should not be queued$/) do
  expect(Resque).to_not receive(:enqueue)
end

When(/^I should recieve a 401 error$/) do
  expect(last_response.status).to eq(401)
end
