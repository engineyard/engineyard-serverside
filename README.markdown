# engineyard-serverside
[![Build Status](https://travis-ci.org/engineyard/engineyard-serverside.png)](https://travis-ci.org/engineyard/engineyard-serverside)

engineyard-serverside is the serverside component of the Engine Yard Cloud CLI.
This gem is invoked either by the Cloud dashboard or by the
[engineyard](https://github.com/engineyard/engineyard) gem through helper gem
[engineyard-serverside-adapter](https://github.com/engineyard/engineyard-serverside-adapter).

## ey.yml options

The ey.yml file allows options to be saved for each environment to which an
application is deployed. Here's an example ey.yml file in ROOT/config/ey.yml:

    $ cat config/ey.yml
    ---
    # 'defaults' applies to all environments running this application.
    defaults:
      bundle_without: test development mygroup  # exclude groups on bundle install (leave blank to remove --without)
      bundle_options: --local                   # add extra options to the bundle install command line (does not override bundle_without)
      copy_exclude:                             # don't rsync the following dirs
      - .git
      maintenance_on_restart: false             # show maintenance page during app restart (default: false except for glassfish and mongrel)
      maintenance_on_migrate: false             # show maintenance page during migrations (default: true)
      precompile_assets: true                   # enables rails assets precompilation (default: inferred using app/assets and config/application.rb)
      precomplie_assets_task: assets:precompile # override the assets:precompile rake task
      precompile_unchanged_assets: true         # precompiles assets even if no changes would be detected (does not check for changes at all).
      asset_dependencies: app/assets            # a list of relative paths to search for asset changes during each deploy.
      assets_strategy: shifting                 # choose an alternet asset management strategy (shifting, cleaning, private, shared)
      asset_roles: :all                         # specify on which roles to compile assets (default: [:app, :app_master, :solo] - must be an Array)
      asset_roles:                              # (Array input for multiple roles) - Use hook deploy/before_compile_assets.rb for finer grained control.
      - :app
      - :app_master
      - :util
      ignore_database_adapter_warning: true     # hide database adapter warning if you don't use MySQL or PostgreSQL (default: false)

    # Environment specific options apply only to a single environment and override settings in defaults.
    environments:
      env_production:
        precompile_unchanged_assets: true       # precompiles assets even if no changes would be detected (does not check for changes at all).
        assets_strategy: shifting               # choose an alternet asset management strategy (shifting, cleaning, private, shared)
        asset_roles: :all                       # specify on which roles to compile assets (default: [:app, :app_master, :solo] - must be an Array)
      env_staging
        assets_strategy: private                # Use an asset management that always refreshes, so staging enviroments don't get conflicts

These options in ey.yml will only work if the file is committed to your
application repository. Make sure to commit this file.

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
