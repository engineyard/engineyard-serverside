# ChangeLog

## NEXT

  * Abort rollbacks if unexpected files are found in the /data/app/releases/ directory because they disrupt the ability to find the previous and latest releases.
  * Accepts flags for git and archive strategies (`--git` and `--archive`) that are passed a uri
  * Changes the name of the Strategy class to Source.

## v2.2.1 (2013-07-29)

  * Fixes deprecation warnings for internal method calls in deploy hooks.

## v2.2.0 (2013-07-25)

  * Updates fallback bundler version to latest v1.3.5.
  * Supports using multiple dependency managers at the same time (bundler, composer, and/or npm)
  * Replaces command runner to address streaming log, idle connection, and random systemu failures.
  * Adds `config/application.rb` to the `asset_dependencies` to trigger asset precompilation.
  * Removes syncing of file modification times during push code operation in deploy. Syncing times occasionally causes unfixable permissions errors.
  * Clarifies inferred asset warning message.
  * Improves some of the maintenance page status messages.
  * Removes poorly encapsulated methods `config.enable_maintenance\_page?` and `config.disable_maintenance_page?`. Relocated to Maintenance class. (Check eydeploy.rb files)
  * Removes deprecated `c` method (use `config` instead)
  * In deploy hooks, deprecates @configuration (use `config`), @node (use `config.node`), and method\_missing access of config methods (use `config.method`).

## v2.1.4 (2013-06-17)

  * Don't reuse assets when there are no assets to reuse
  * Better composer support.

## v2.1.3 (2013-06-05)

  * Ensure LANG is set when gem install is run.

## v2.1.2 (2013-05-31)

  * Fix rails database.yml for sqlite-only deployments
  * Auto-update composer before installing (php)

## v2.1.1 (2013-05-30)

  * Fixes a problem where Set#first was called in a ruby version that doesn't support it.

## v2.1.0 (2013-05-28)

  * Bumps default bundler version to latest 1.3.4
  * Fixes a race condition during deploy where `current` symlink was not moved atomically.
  * Don't precompile assets when git-diff shows no changes to `asset_dependencies`
  * Supports new ey.yml option `asset_dependencies` which is a list of relative paths to search for asset changes each deploy.
    * The default `asset_dependencies` are: app/assets lib/assets vendor/assets Gemfile.lock config/routes.rb
  * Supports new ey.yml option `precompile_unchanged_assets: true` compiles assets even if no changes would be detected.
  * Supports new ey.yml option `precompile_assets_task: taskname` which overrides the default `assets:precompile`
  * Supports new ey.yml option `asset_strategy` which supports: `shared`, `private`, `cleaning`, or `shifting`.
    * The default asset strategy is `shifting` which is the same behavior as previous versions.
    * See `README.markdown` or `lib/engineyard-serverside/rails_assets/strategy.rb` for full explanation.
  * Supports new ey.yml option `bundle_options` which can be used to specify additional bundle install command line options.
  * Supports setting of ey.yml option `bundle_without` to nil to remove `--without` from the bundle install command.
  * Refactor dependency management (bundler, npm, none) to allow more flexibility (may break existing eydeploy.rb files)
  * Supports new ey.yml option `eydeploy_rb: false` which enables or disables eydeploy.rb file loading. (defaults to enabled)
  * Changes the order of eydeploy.rb loading to happen after ey.yml is parsed during deploy.

## v2.0.7 (2013-05-16)

  * Fix encoding errors in logs when non-ascii characters are displayed.

## v2.0.6 (2013-04-08)

  * Fix for command line config option `--config precompile_assets:true/false` which was being interpreted as a string.
  * Don't exclude the `RAILS_ENV` Gemfile group from bundle install. (i.e. don't do `--without development` in `development` mode)

## v2.0.5 (2013-02-12)

  * Change concurrency code to use a simple threaded model.
  * Clean up local branches that might interfere with the git checkout.

## v2.0.4 (2012-12-17)

  * Supports new ey.yml option to control on which roles asset precompilation happens.
    * Must be a YAML Array syntax (using :app, :app\_master, :solo, :util) or :all.
    * Syntax: `asset_roles: :all (default is to exclude :util but include all others. [:app, :app_master, :solo])`
  * Adds `RAILS_GROUPS=assets` to rake assets:precompile to improve asset compilation performance.
  * Records exceptions raised during deploy into the deploy log when possible.
  * Fixes a bug where permissions problems may cause integrate action to fail.
  * Fixes a problem where "maintenance page still up" notice would stay on Cloud Dashboard too long. Downgraded message severity.
  * Garbage collect git at the end of each deploy. First one may take a while but the next ones will be faster and reduce extra disk usage.

## v2.0.3 (2012-09-24)

  * Make sure command line --config options get turned from strings into booleans if needed

## v2.0.2 (2012-09-19)

  * Only symlink shared config files that actually exist.
  * Don't display the database adapter warning when `nodatabase.yml` is present.
  * chown shared/bundled\_gems dir to deploy user to ensure bundle install works.

## v2.0.1 (2012-08-21)

  * Reduce the number of deprecation warnings.

## v2.0.0 (2012-08-16)

  * Default bundler version is now 1.1.5.
  * Deploy hooks now have access to `account_name` and `environment_name`.
  * Improves deploy output, especially for `--verbose`.
  * Sends all log output through a new Shell object that formats and adds timestamps.
  * Loads `ey.yml` or `config/ey.yml` to customize deploy settings.
  * Supports new ey.yml options to control automatic maintenance page:
  * `maintenance_on_restart: true or false (default: false except for glassfish and mongrel)`
  * `maintenance_on_migrate: true or false (default: true)`
  * Don't remove maintenance pages that weren't put up during this deploy if maintenance options (above) are set to false.
  * Supports new ey.yml options to control asset precompilation:
  * `precompile_assets: true or false (default: inferred using app/assets and config/application.rb)`
  * Supports new ey.yml option to ignore the missing database adapter warning:
  * `ignore_database_adapter_warning: true (default: false)`
  * Give better feedback when maintenance is enabled/disabled (or not).
  * Output a better error when a deploy hook fails.
  * Compile assets before maintenance page is installed.
  * Provide run! and sudo! to deploy hooks. If the command exits non-zero the deploy hook will fail, stopping the deploy.

## v1.6.4 (2012-04-26)

  *

## v1.6.3 (2012-03-26)

  *

## v1.6.2 (2012-03-26)

  *

## v1.6.1 (2012-03-23)

  *

## v1.6.0 (2012-03-23)

  * Replace Open4 with systemu

## v1.5.34 (2012-03-22)

  *

## v1.5.33 (2012-03-19)

  *

## v1.5.32 (2012-03-15)

  *

## v1.5.31 (2012-03-15)

  *

## v1.5.30 (2012-02-29)

  *

## v1.5.29 (2012-02-06)

  * This version has been pulled before release.

## v1.5.28 (2012-02-02)

  * Fix incompatibility issues between Open4 and Ruby 1.9

## v1.5.27 (2012-01-27)

  * Add celluloid for Ruby 1.9 compatible futures in preparation for internal 1.9 upgrade.
  * If the application Gemfile contains sqlite3 but no other recognized database
    adapter, generate a SQLite database.yml and print a warning.

## v1.5.26 (2012-01-21)

  * Adds timestamps to deploy logs

## v1.5.25 (2012-01-13)

  *

## v1.5.24 (2012-01-12)

  *

## v1.5.23 (2012-01-11)

  *

## v1.5.22 (2011-12-09)

  * Add LANG to restart command.

## v1.5.21 (2011-12-07)

  *

## v1.5.20 (2011-12-07)

  * Fix a bug where added instances would sometimes be unable to bundle.

## v1.5.19 (2011-11-26)

  *

## v1.5.18 (2011-11-26)

  * Fix a bug where gems were cleaned on every run.

## v1.5.17 (2011-11-16)

  *

## v1.5.16 (2011-11-15)

  *

## v1.5.15 (2011-11-10)

  * Last release was built with a rubygems that has the Syck problem. Re-releasing. (This gem was never released into the wild)

## v1.5.14 (2011-11-10)

  * Really seriously fix 32/64 bit system problems this time.

## v1.5.13 (2011-11-07)

  *

## v1.5.12 (2011-11-02)

  *

## v1.5.11 (2011-11-02)

  * Add ey_services_config_deploy.yml file through EY::InstanceAPI during deploy.
  * Bump default bundler version to 1.0.21

## v1.5.10 (2011-11-01)

  * Re-bundle gems if there is no version file found with which to compare.
  * Don't fail is pre-compilation fails. Let users know we're going to try to precompile assets.

## v1.5.9 (2011-10-26)

  *

## v1.5.8 (2011-10-26)

  *

## v1.5.7 (2011-10-26)

  *

## v1.5.6 (2011-10-25)

  *

## v1.5.5 (2011-10-25)

  *

## v1.5.4 (2011-10-21)

  *

## v1.5.3 (2011-10-21)

  * bundle\_without: ey.yml option allows you to specify custom bundle install --without string (list of space separated groups, replaces the default 'test development')
  * Refactor how bundler options are loaded.

## 1.5.2 (2011-10-18)

  * Improve clarity of warning output.

## 1.5.1 (2011-10-13)

  * Use unset instead of env -i to exclude Bundler env.

## 1.5.0 (2011-10-06)

  * Remove support for Bundler 0.9.x
  * Add warning when no database adapter is found in the Gemfile.lock

## 1.4.16 (2011-09-27)

  * Deployment previously failed when the git repo had only a single commit.

## 1.4.15 (2011-09-27)

  * Add 'before_compile_assets.rb' and 'after_compile_assets.rb' deploy hooks
  * Run `rake assets:precompile` if it is available and enabled for Rails 3.1 apps
  * Treat 'public/assets' as a shared directory if it is managed by 'rake assets:precompile'
  * Beta Node.js support for EY Labs

## 1.4.14 (2011-09-27)

## 1.4.13 (2011-09-21)

## 1.4.12 (2011-09-19)

## 1.4.11 (2011-09-15)

## 1.4.10 (2011-09-13)

## 1.4.9 (2011-09-12)

## 1.4.8 (2011-09-08)

## 1.4.7 (2011-09-07)

## 1.4.6 (2011-09-07)

## 1.4.5 (2011-09-07)

## 1.4.4 (2011-09-07)

## 1.4.3 (2011-09-06)

## 1.4.2 (2011-08-03)

## 1.4.1 (2011-02-17)

## 1.4.0 (2010-11-18)

## 1.3.7 (2010-11-17)

## 1.3.6 (2010-11-08)

  * Abort deploy when `git fetch` fails
