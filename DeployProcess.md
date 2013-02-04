# Deploy Process

A breakdown of the deploy process.

This is an in-progress breakdown of the deploy process. It is not meant to be
exact, but to serve as a reference. Most of the commands use placeholder text
for parts that would be determined programatically. Many of the commands use
ruby code to determine how the shell command should run, and this is not shown.


## Step 1: Get Application Code

Before we can deploy anything we need code. There are many ways to get the code.

* Fetch code from github.com
* Download bundled code from S3
* Download bundled code from elsewhere
* Upload code directly

First we need to generate a permissive GIT_SSH script to be used by git when fetching the app.

    $ mkdir -p app/shared/config
    $ [[ -x app/shared/config/app-ssh-wrapper ]] || cat > app/shared/config/app-ssh-wrapper <<'SSH'
      #!/bin/sh
      unset SSH_AUTH_SOCK
      ssh -o CheckHostIP=no -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o LogLevel=INFO -o IdentityFile=#{paths.deploy_key} -o IdentitiesOnly=yes $*
      SSH
    $ chmod 0700 app/shared/config/app-ssh-wrapper

Then we fetch the code

    $ GIT_SSH=app-ssh-wrapper git clone git@github.com:user/app.git app/source-cache
    $ GIT_SSH=app-ssh-wrapper git --work-tree app/source-cache fetch origin

Some strategies may require checking out a specified version or possibly
unpacking an archive.

    $ git --work-tree app/source-cache checkout --detach branch-name
      git submodule sync && git submodule update --init && git clean -dfq

On multi-server deploys, we have taken the approach of performing the
application code fetching on one server and rsyncing to other servers
to guarantee sameness. It also reduces the load on the server that is
serving the application code.

    $ rsync --delete -aq -e 'ssh -i ~/.ssh/internal -o StrictHostKeyChecking=no \
      -o PasswordAuthentication=no' app/source-cache user@example.com:app/source-cache

At the end of this step, all servers must have a working directory with the exact application code for deploy.


## Step 2: Prepare Active Release Directory

Make an active release directory and copy the files from the cache to the
directory. These are the actual files that will be served.

A different directory is made instead of using the cache or the live directory
so that deploys can fail or be stopped withouth altering the state of the server
or breaking the ability to redeploy after a failure.

Create a directory where the active code will live.

    $ mkdir -p app/releases/1234567890

Copy the code into it the new directory.

    $ rsync --delete -aq --exclude '.git' app/source-cache app/releases/1234567890/

Ensure permissions are correct.

    $ sudo chown -R user:group app/releases/1234567890

Make a note of what revision is active.

    $ git --work-tree app/source-cache show --pretty=format:"%H" | head -1 > app/releases/1234567890/REVISION

At the end of this step, all servers must have an active release directory that is ready for application specific setup.


## Step 3: Setup Active Release

Run various commands that prepare the application (application dependent)

If a Gemfile is detected, run the appropriate bundler command, installing bundler if necessary.

First, remove old gems if the ruby version or server version has changed.

    $ ruby -v | diff - app/bundled-gems/RUBY_VERSION >/dev/null 2>&1 &&
      uname -a | diff - app/bundled-gems/SYSTEM_VERSION >/dev/null 2>&1 ||
      rm -Rf bundled-gems


Next, install the correct version of bundler if it is not already. The version is parsed from the Gemfile.lock, or a default version is used if one is not found.

    $ export GIT_SSH=app-ssh-wrapper && \
      export LANG="en_US.UTF-8" && \
      unset RUBYOPT BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE && \
      gem install bundler -v VERSION

Then run bundle install to install the gems for the application.

    $ export GIT_SSH=app-ssh-wrapper && \
      export LANG="en_US.UTF-8" && \
      unset RUBYOPT BUNDLE_PATH BUNDLE_FROZEN BUNDLE_WITHOUT BUNDLE_BIN BUNDLE_GEMFILE && \
      ruby -S bundle _VERSION_ install --deployment \
      --gemfile app/releases/1234567890/Gemfile \
      --path app/shared/bundled-gems \
      --binstubs app/shared/bundled-gems/binstubs \
      --without test development

Save the version info for the set of bundled gems. (note: the mkdir is there, but seems out of order to me)

    $ mkdir -p app/shared/bundled-gems && chown user:group app/shared/bundled-gems
    $ ruby -v > app/shared/bundled-gems/RUBY_VERSION && \
      uname -a > app/shared/bundled-gems/SYSTEM_VERSION

If npm is detected, run the appropriate node commands to install libraries.

    $ cd app/releases/1234567890 && npm install

Setup Engine Yard external services.

    $ sudo which /usr/local/ey_resin/ruby/bin/ey-services-setup && \
      sudo /usr/local/ey_resin/ruby/bin/ey-services-setup app

Symlink shared files and dirs into the active release directory.

    $ chmod -R g+w app/releases/1234567890
    $ rm -rf app/releases/1234567890/log app/releases/1234567890/public/system app/releases/1234567890/tmp/pids
    $ mkdir -p app/releases/1234567890/tmp
    $ mkdir -p app/releases/1234567890/public
    $ mkdir -p app/releases/1234567890/config
    $ ln -nfs app/shared/log app/releases/1234567890/log
    $ ln -nfs app/shared/system app/releases/1234567890/public/system
    $ ln -nfs app/shared/pids app/releases/1234567890/tmp/pids
    $ find app/shared/config -type f -not -name 'database.yml' \
      -exec ln -s {} app/releases/1234567890/config \;
    $ if [ -f "app/shared/config/database.yml" ]; then
        ln -nfs app/shared/config/database.yml app/releases/1234567890/config/database.yml;
      fi
    $ if [ -f "app/shared/config/newrelic.yml" ]; then
        ln -nfs app/shared/config/newrelic.yml app/releases/1234567890/config/newrelic.yml;
      fi
    $ if [ -f "app/shared/config/mongrel_cluster.yml" ]; then
        ln -nfs app/shared/config/mongrel_cluster.yml app/releases/1234567890/config/mongrel_cluster.yml;
      fi

Compile assets if this is a rails application. Various checks go into deciding whether or not this should happen. I have not copied them here.

    $ cd app/releases/1234567890 && PATH=#{paths.binstubs}:$PATH #{config.framework_envs} rake assets:precompile RAILS_GROUPS=assets"


## Step 4: Maintenance Mode, Migration

If maintenance mode has been requested, enter maintenance mode by copying the
maintenance page to the configured location.

    $ mkdir -p app/shared/system/
    $ cp app/releases/1234567890/public/maintenance.html \
      app/shared/system/maintenance.html

Run the migrate command, if given.

    $ cd app/releases/1234567890 && \
      PATH=app/shared/bundled-gems/binstubs:$PATH \
      RAILS_ENV=production RACK_ENV=production NODE_ENV=production MERB_ENV=production \
      rake db:migrate

Step 5: Restart The Application Servers

Change the "current" symlink to point to the newest release.

    $ rm -f app/current && ln -nfs app/releases/1234567890 app/current && \
      find app/current -not -user user -or -not -group group -exec chown user:group {} +

Restart the application servers.

    $ LANG="en_US.UTF-8" /engineyard/bin/app_name deploy

Remove the maintenance page, if it was enabled.

    $ rm -f app/shared/system/maintenance.html

Step 6: Clean Up

Remove all but the last 3 releases, leaving the current release and the 2
previous releases.

    $ sudo ls -r app/releases | tail -n +4 | xargs -I@ rm -rf app/releases/@"

Garbage collect the git repository cache.

    $ git --work-tree app/source-cache gc

Deploy is complete.

