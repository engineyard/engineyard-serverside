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

  Scenario Outline: Running a callback with both Ruby and Executable deploy hooks
    Given my app has a <Callback Name> executable deploy hook
    Given my app has a <Callback Name> ruby deploy hook
    When I run the <Callback Name> callback
    Then the <Callback Name> ruby deploy hook is executed
    But the <Callback Name> executable deploy hook is not executed

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

  Scenario Outline: Running a callback with a Ruby service hook
    Given I have a service named selective
    And my service has a <Callback Name> ruby hook
    When I run the <Callback Name> callback
    Then the <Callback Name> ruby hook for my service is executed

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

  Scenario Outline: Running a callback with an executable service hook
    Given I have a service named selective
    And my service has a <Callback Name> executable hook
    When I run the <Callback Name> callback
    Then the <Callback Name> executable hook for my service is executed

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

  Scenario Outline: Running a callback with both Ruby and Executable service hooks
    Given I have a service named selective
    Given my service has a <Callback Name> executable hook
    Given my service has a <Callback Name> ruby hook
    When I run the <Callback Name> callback
    Then the <Callback Name> ruby hook for my service is executed
    But the <Callback Name> executable hook for my service is not executed

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

  Scenario Outline: Running a callback with botth service hooks and deploy hooks
    Given my app has a <Callback Name> executable deploy hook
    And I have a service named selective
    Given my service has a <Callback Name> ruby hook
    When I run the <Callback Name> callback
    Then the <Callback Name> ruby hook for my service is executed
    And the <Callback Name> executable deploy hook is executed

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


  Scenario Outline: Executable hooks without the executable bit get skipped
    Given my app has a <Callback Name> executable deploy hook
    But my app's <Callback Name> executable deploy hook is not actually executable
    And I have a service named selective
    Given my service has a <Callback Name> executable hook
    When I run the <Callback Name> callback
    Then the <Callback Name> executable hook for my service is executed
    But the <Callback Name> executable deploy hook is not executed

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

    @error
  Scenario Outline: Ruby hooks with syntax errors cause an error
    Given my app has a <Callback Name> ruby deploy hook
    And I have a service named selective
    And my service has a <Callback Name> ruby hook
    But my service's <Callback Name> ruby hook contains syntax errors
    When I run the <Callback Name> callback
    Then I see a notice about the <Callback Name> syntax error
    But my service's <Callback Name> ruby hook is not executed
    And the <Callback Name> ruby deploy hook is not executed

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


    #@failure
  #Scenario: Ruby hook errors cause an error

    #@failure
  #Scenario: Executable hooks that are not actually executable cause an error
