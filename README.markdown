# engineyard-serverside

engineyard-serverside is the serverside component of the Engine Yard AppCloud CLI. This gem is invoked either by the AppCloud dashboard, or the [engineyard](http://github.com/engineyard/engineyard) gem. All information that this gem needs to perform a deploy of an application is passed in on the command line. The main options are as follows:

    -r, --repo=REPO                        # Remote repo to deploy
    -v, --verbose                          # Verbose output
    --config=CONFIG                        # Additional configuration
    -e, --framework-env=FRAMEWORK_ENV      # Web framework environment
    -m, --migrate=MIGRATE                  # Run migrations/post-deploy instructions with this deploy
    --stack=STACK                          # Web stack (so we can restart it correctly)
    --instances=one two three              # Instances in cluster
    -b, --ref, --tag, --branch=BRANCH      # Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA
    -a, --app=APP                          # Application to deploy
    --environment-name=ENV_NAME            # Environment name
    --account-name=ACCOUNT_NAME            # Account name

### Running the spec suite

Bundler doesn't work on ruby 1.8.6-p287, which is what 'ey\_resin' currently provides.
To test engineyard-serverside under the same ruby, you can run:

  gem build engineyard-serverside.gemspec
  gem install --local --development --conservative ./engineyard-serverside-<VERSION>.gem
  rake

Due to the nature of --development, that gem install command can take a VERY long time.
If you get tired of waiting, you can manually install the indicated versions of
rake and rspec. Check the gemspec for current requirements.
At the time of this writing, rspec 1.3.0 was the last version known to work on 1.8.6.

Set the 'VERBOSE' environment variable to something to get full output from failing commands.
