# ChangeLog

## NEXT

  * Fix #31: Use resin to run engineyard-serverside when it's available

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
