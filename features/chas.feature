Feature: Posting some JSON queues a job

  Scenario: Triggering a run
    Given I want to queue a scraper
    Then the TurbotDockerRunnner job should be queued
    When I trigger a run

  Scenario: Posting some JSON
    Given I want to queue a scraper
    And I specify an incorrect API key
    Then the TurbotDockerRunnner job should not be queued
    When I trigger a run
    And I should recieve a 401 error
