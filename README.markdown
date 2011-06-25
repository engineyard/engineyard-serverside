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

## Development and testing

### Installing Ruby 1.8.6p287

The project automatically detects, installs/patches and uses ruby-1.8.6-p287 (used by ey_resin on customer instances).

The .rvmrc essentially runs the following:

    rvm install ruby-1.8.6-p287 --patch lib/vendor/ruby_1.8.6_openssl.patch
    rvm gemset create ey-ss
    rvm use ruby-1.8.6-p287@ey-ss
    rvm rubygems 1.3.6

### Running tests

Bundler doesn't work for ruby 1.8.6, so for the moment until we upgrade ey_resin, install the dependencies directly:

    gem install rake -v 0.8.7
    gem install rspec -v 1.3.0
    rake

Running the tests now requires nodejs and the npm package manager installed too.

### Debugging

Want ruby-debug? You need some specific versions of things (https://gist.github.com/1034765)

    gem install linecache -v 0.45
    gem install ruby-debug-base -v 0.10
    gem install ruby-debug -v 0.10

