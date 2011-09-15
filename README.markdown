# engineyard-serverside

engineyard-serverside is the serverside component of the Engine Yard AppCloud CLI. This gem is invoked either by the AppCloud dashboard, or the [engineyard](http://github.com/engineyard/engineyard) gem. All information that this gem needs to perform a deploy of a ruby rack application is passed in on the command line. The main options are as follows:

    -r, --repo=REPO                        # Remote repo to deploy
    -v, --verbose                          # Verbose output
    --config=CONFIG                        # Additional configuration
    -e, --framework-env=FRAMEWORK_ENV      # Ruby web framework environment
    -m, --migrate=MIGRATE                  # Run migrations with this deploy
    --stack=STACK                          # Web stack (so we can restart it correctly)
    --instances=one two three              # Instances in cluster
    -b, --ref, --tag, --branch=BRANCH      # Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA
    -a, --app=APP                          # Application to deploy

