Feature: Showing the version
  In order to know what iteration of engineyard-serverside I'm using, I want to
  be able to have it print out the version.

  Scenario: User issues the vesion command
    When I run `engineyard-serverside version`
    Then the current version is displayed
