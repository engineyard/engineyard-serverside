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

## ey.yml options

The ey.yml file allows options to be saved for each environment to which an application is deployed. Here's an example ey.yml file in RAILS_ROOT/config/ey.yml:

    $ cat config/ey.yml
    ---
    environments:
      env_production:
        bundle_without: test development mygroup  # exclude groups on bundle install
        copy_exclude:                             # don't rsync the following dirs
        - .git
        maintenance_on_restart: false             # show maintenance page during app restart (default: false except for glassfish and mongrel)
        maintenance_on_migrate: false             # show maintenance page during migrations (default: true)
        precompile_assets: true                   # enables rails assets precompilation (default: inferred using app/assets and config/application.rb)
        precomplie_assets_task: assets:precompile:primary # override the assets:precompile rake task
        precompile_unchanged_assets: true         # precompiles assets even if no changes would be detected (does not check for changes at all).
        asset_roles: :all                         # specify on which roles to compile assets (default: [:app, :app_master, :solo] - must be an Array)
        asset_roles:                              # (Array input for multiple roles) - Use hook deploy/before_compile_assets.rb for finer grained control.
        - :app
        - :app_master
        - :util
        ignore_database_adapter_warning: true     # hide database adapter warning if you don't use MySQL or PostgreSQL (default: false)


These options in ey.yml will only work if the file is committed to your application repository. Make sure to commit this file.

### Running the spec suite (ruby 1.8.7+)

Install required gems:

    which bundle >/dev/null || gem install bundler
    bundle install

Running tests:

    bundle exec rake

Bundler will take care of installing and running proper (older versions) of gems.

### Running the spec suite (ruby 1.8.6)

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
