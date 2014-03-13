# engineyard-serverside
[![Build Status](https://travis-ci.org/engineyard/engineyard-serverside.png)](https://travis-ci.org/engineyard/engineyard-serverside)

engineyard-serverside is the serverside component of the Engine Yard Cloud CLI.
This gem is invoked either by the Cloud dashboard or by the
[engineyard](https://github.com/engineyard/engineyard) gem through helper gem
[engineyard-serverside-adapter](https://github.com/engineyard/engineyard-serverside-adapter).

## ey.yml Configuration

The `ey.yml` file allows options to be saved for each environment to which an
application is deployed.

A typical Rails application will have a `config/ey.yml` like this:

    ---
    # This is all you need for a typical rails application.
    defaults:
      migrate: true
      migration_command: rake db:migrate
      precompile_assets: true

The following `ey.yml` file shows other things that can be customized.
A typical application will not need most of these options.

    ---
    # 'defaults' applies to all environments running this application.
    # Only set these options if needed. The defaults are correct for most applications.
    defaults:
      bundler: detect                           # By default, bundler is detected via Gemfile. Options: true: always run bundler; false: never run bundler
      composer: detect                          # By default, composer is detected via composer.lock. Options: true: always run composer; false: never run composer
      npm: detect                               # By default, npm is detected via package.json. Options: true: always run npm; false: never run npm
      bundle_without: GROUP1 GROUP2             # exclude groups on bundle install (default: test development)
      bundle_options: --OPTION                  # extra bundle install options (--local, --quiet, etc; does not override bundle_without)
      copy_exclude:                             # don't rsync the following dirs (some people like to skip .git)
      - SOME_LARGE_DIR 
      maintenance_on_restart: false             # show maintenance page during app restart (default: false except for glassfish and mongrel)
      maintenance_on_migrate: true              # show maintenance page during migrations (default: true)
      precompile_assets: true                   # enables rails assets precompilation (default: inferred using app/assets and config/application.rb)
      precomplie_assets_task: assets:precompile # override the assets:precompile rake task
      precompile_unchanged_assets: false        # if true, does not check git for changes before precompiling assets.
      asset_dependencies:                       # a list of relative paths to search for asset changes during each deploy.
      - app/assets                              # default
      - lib/assets                              # default
      - vendor/assets                           # default
      - Gemfile.lock                            # default
      - config/routes.rb                        # default
      - config/application.rb                   # default
      - config/requirejs.yml                    # custom option (be sure to include defaults if you specify this option)
      asset_strategy: shifting                  # choose an alternet asset management strategy. See rails_assets/strategy.rb for more info.
      asset_roles: :all                         # specify on which roles to compile assets (default: [:app, :app_master, :solo])
      ignore_database_adapter_warning: true     # hide database adapter warning if you don't use MySQL or PostgreSQL (default: false)
      ignore_gemfile_lock_warning: true         # hide warning when Gemfile is present but Gemfile.lock is missing. (default: false)
      gc: false                                 # if true, run repository garbage collection every deploy. (default: git will run gc as needed)

    # Environment specific options apply only to a single environment and override settings in defaults.
    environments:
      env_production:
        precompile_unchanged_assets: true       # precompiles assets even if no changes would be detected (does not check for changes at all).
        asset_strategy: shifting                # choose an alternet asset management strategy (shifting, cleaning, private, shared)
        asset_roles: :all                       # specify on which roles to compile assets (default: [:app, :app_master, :solo] - must be an Array)
      env_staging
        asset_strategy: private                 # Use an asset management that always refreshes, so staging enviroments don't get conflicts

These options in `ey.yml` will only work if the file is committed to your
application repository. Make sure to commit this file. Different branches
may also have different versions of this file if necessary. The ey.yml file
found in the deploying commit will be used for the current deploy.

### Rails Assets

If `precompile_assets` is not set, asset compilation will be detected and
failures may be ignored. Set `precompile_assets` to true or false to ensure
proper behavior. When precopmile_assets is true, `git diff` will be used to
detect changes to the path names specified in `asset_dependencies` since the
revision of the last successful release. When `precompile_unchanged_assets` is
true, assets will always be compiled and the `git diff` detection will not run.

#### Strategies

A number of asset persistence strategies are supported by default. Choose one
and then customize using deploy hooks if necessary.

`private` - Precompile assets fresh every time. Shared assets are not symlinked
and assets stay with the release that compiled them. The assets of the previous
deploy are symlinked as into the current deploy to prevent errors during deploy.
When no assets changes are detected, the deploy uses rsync to copy the previous
release's assets into the current assets directory.

`shared` - Basic shared assets. Precompiled assets go into a single shared
assets directory. The assets directory is never cleaned, so a deploy hook should
be used to clean assets appropriately. When no assets changes are detected,
shared directory is only symlinked and precompile task is not run.

`cleaning` - Precompiled assets are shared across all deploys. Before compiling
the active deploying assets, all assets not referenced by the manifest.yml from
the previous deploy are removed. After cleaning, the new assets are compiled
over the top. The result is an assets dir that contains the last assets and the
current assets. When no assets changes are detected, shared directory is only
symlinked and cleaning and precompile tasks are not run.

`shifting` - The default behavior and the one used since the beginning of asset
support in engineyard-serverside. Assets are compiled into a fresh shared
directory. Previous shared assets are shifted to a last_assets directory to
prevent errors during deploy. When no assets changes are detected, the two
shared directories are symlinked into the active release without any changes.

### Invoking serverside manually

All information that this gem needs to perform a deploy of an application is
passed in on the command line. Command line interaction is performed through
[engineyard-serverside-adapter](https://github.com/engineyard/engineyard-serverside-adapter).
Refer to the adapter gem or the source code here for details on the command line
options.

The easiest way to run a serverside command manually is to run a normal deploy
with the verbose option from the command line, then copy the
engineyard-serverside command from the log and paste it into a terminal on the
remote machine. Running manually should usually be unnecessary, but could be
used to debug problems.

### Running the spec suite (ruby 1.8.7+)

Install required gems:

    which bundle >/dev/null || gem install bundler
    bundle install

Running tests:

    bundle exec rake

Bundler will take care of installing and running proper (older versions) of gems.

### Running the spec suite (ruby 1.8.6)

Bundler doesn't work on ruby 1.8.6-p287, which is what `ey_resin` provided
to older instances. To test engineyard-serverside under the same ruby, run:

    gem build engineyard-serverside.gemspec
    gem install --local --development --conservative ./engineyard-serverside-<VERSION>.gem
    rake

Due to the nature of --development, that gem install command can take a VERY
long time. If you get tired of waiting, you can manually install the indicated
versions of rake and rspec. Check the gemspec for current requirements.
At the time of this writing, rspec 1.3.0 was the last version known to work
on 1.8.6.

Set the 'VERBOSE' environment variable to something to get full output from
failing commands.

### Releasing

To release the engineyard-serverside gem, use the command below and then follow
the instructions it outputs.

    bundle exec rake release

This will remove the .pre from the current version, then bump the patch level
and add .pre after. A git tag for the version will also be added.

New versions of engineyard-serverside will not be used by Cloud or the
engineyard gem until upgraded gems have been pushed. Refer to the
[engineyard gem](https://github.com/engineyard/engineyard) release
instructions for more details.

### Testing manually on a server

The following 2 commands will install the current working copy on an instance:

    bundle exec rake install_on[account/envname]
    ey deploy --serverside-version VERSION -e envname -a appname -r branch-to-checkout --no-migrate -v

If you don't have an environment running on Engine Yard Cloud, you'll need to do
a bit of hacking of both commands. You can look at the Rakefile to see how
install_on works. It is simple to adapt it to installing on specified servers.

Next you'll have to run the deploy command manually on the instance. The easiest
way to do that is to take an existing serverside command and modify it. An
engineyard-serverside command can be extracted from a verbose log for another
application's deploy, and then modified. The command looks like this:

    bash -lc '/usr/local/ey_resin/ruby/bin/engineyard-serverside _2.1.0.rc1_ deploy --account-name account --app appname --config '\''{"input_ref":"testing","deployed_by":"Märtîn ☃ Èmdé"}'\'' --environment-name envname --framework-env production --instance-names ec2-255-255-255-255.compute-1.amazonaws.com:util --instance-roles ec2-255-255-255-255.compute-1.amazonaws.com:util localhost:solo --instances ec2-255-255-255-255.compute-1.amazonaws.com localhost --no-migrate --ref 5a6de57ca3ce3c51df18cfff0cbea87f2f07872a --repo git://github.com/engineyard/todo.git --stack nginx_passenger3 --verbose'

Run that from any primary web server instance and be sure to use "localhost"
for the instance you're running on instead of its public address.
