Feature: Running A Deploy Hook
  In order to inject needed extra steps into the deploy process, I want to be able
  to provide hooks for various pre-defined callbacks. Meanwhile, serverside needs
  to know how to execute such hooks.

  Background:
    Given my account name is TestAccount
    And my app's name is george
    And my app lives in an environment named george_fliggerbop
    And the framework env for my environment is staging

  Scenario Outline: Running a callback
    When I run `engineyard-serverside hook <Callback Name> --app=george --environment-name=george_fliggerbop --account-name=TestAccount --framework-env=staging`
    Then I see output indicating that the <Callback Name> hooks were processed

    Examples:
      | Callback Name         |
      | before_deploy         |
      | before_bundle         |
      | after_bundle          |
      | before_compile_assets |
      | after_compile_assets  |
      | before_migrate        |
      | after_migrate         |
      | before_symlink        |
      | after_symlink         |
      | before_restart        |
      | after_restart         |
      | after_deploy          |

  Scenario Outline: Running a callback with no hooks present
    Given my app has no deploy hooks
    And my app has no service hooks
    When I run the <Callback Name> callback
    Then I see a notice that the <Callback Name> callback was skipped

    Examples:
      | Callback Name         |
      | before_deploy         |
      | before_bundle         |
      | after_bundle          |
      | before_compile_assets |
      | after_compile_assets  |
      | before_migrate        |
      | after_migrate         |
      | before_symlink        |
      | after_symlink         |
      | before_restart        |
      | after_restart         |
      | after_deploy          |

  Scenario Outline: Running a callback with a Ruby deploy hook
    Given my app has a <Callback Name> ruby deploy hook
    When I run the <Callback Name> callback
    Then the <Callback Name> ruby deploy hook is executed

    Examples:
      | Callback Name         |
      | before_deploy         |
      | before_bundle         |
      | after_bundle          |
      | before_compile_assets |
      | after_compile_assets  |
      | before_migrate        |
      | after_migrate         |
      | before_symlink        |
      | after_symlink         |
      | before_restart        |
      | after_restart         |
      | after_deploy          |

  Scenario Outline: Running a callback with an Executable deploy hook
    Given my app has a <Callback Name> executable deploy hook
    When I run the <Callback Name> callback
    Then the <Callback Name> executable deploy hook is executed

    Examples:
      | Callback Name         |
      | before_deploy         |
      | before_bundle         |
      | after_bundle          |
      | before_compile_assets |
      | after_compile_assets  |
      | before_migrate        |
      | after_migrate         |
      | before_symlink        |
      | after_symlink         |
      | before_restart        |
      | after_restart         |
      | after_deploy          |
  #Scenario Outline: Running a callback with an Executable deploy hook
    #Given the george app has a <Callback Name> executable hook
    #When I run `engineyard-serverside hook <Callback Name>`

  #Scenario: Running a callback with both Ruby and Executable deploy hooks

  #Scenario: Running a callback with a Ruby service hook

  #Scenario: Running a callback with an Executable service hook

  #Scenario: Running a callback with both Ruby and Executable service hooks

  #Scenario: Running a callback with both service hooks and deploy hooks

    #@failure
  #Scenario: Ruby hooks with syntax errors cause an error

    #@failure
  #Scenario: Executable hooks that are not actually executable cause an error
