# engineyard-serverside

engineyard-serverside (known as ey-serverside or SS) is the serverside component of the Engine Yard AppCloud CLI. This gem is invoked either by the AppCloud dashboard, or the [engineyard](http://github.com/engineyard/engineyard) gem. All information that this gem needs to perform a deploy of a ruby rack application is passed in on the command line. The main options are as follows:

    -r, --repo=REPO                        # Remote repo to deploy
    -v, --verbose                          # Verbose output
    --config=CONFIG                        # Additional configuration
    -e, --framework-env=FRAMEWORK_ENV      # Ruby web framework environment
    -m, --migrate=MIGRATE                  # Run migrations with this deploy
    --stack=STACK                          # Web stack (so we can restart it correctly)
    --instances=one two three              # Instances in cluster
    -b, --ref, --tag, --branch=BRANCH      # Git ref to deploy, defaults to master. May be a branch, a tag, or a SHA
    -a, --app=APP                          # Application to deploy

## Developing and Testing

Once you have the source locally, to download the dependent gems and run the tests:

    $ bundle
    $ bundle exec rake

The project's tests do not require AppCloud or running VMs.

To do QA testing of SS on an AppCloud, you need to release a preview of the RubyGem, install it on a target AppCloud environment, and specify locally that you wish to us the released gem for your CLI commands:

    $ gem build gem build engineyard-serverside.gemspec
      Successfully built RubyGem
      Name: engineyard-serverside
      Version: 1.4.3.pre
      File: engineyard-serverside-1.4.3.pre.gem
    $ ey-gem upload engineyard-serverside-1.4.3.pre.gem --server=public
    $ cd /path/to/myapp
    $ export ENGINEYARD_SERVERSIDE_VERSION=1.4.3.pre
    $ ey ssh "sudo /usr/local/ey_resin/ruby/bin/gem sources -a http://gems.engineyard.com" --all
    $ ey ssh "sudo /usr/local/ey_resin/ruby/bin/gem install engineyard-serverside -v 1.4.3.pre" --all
    $ ey deploy

## Bugs, patches and pull requests

First, ensure there is an SS ticket in YouTrack, such these [SS tickets](https://tickets.engineyard.com/issues/SS), for the feature/bug being developed.

Please do development in branches with the format SS-<TICKETNO>-branch-name.

    git checkout -b SS-123-branch-name

As you continue developing, push the branch to github.

    git push origin SS-123-branch-name

Once you are ready to share your branch for discussion/review, create a pull request for this branch. As you continue development, any new commits are automatically assigned to the pull request.

* Reference the YouTrack ticket URL in the Pull Request description (https://tickets.engineyard.com/issue/SS-123)
* Reference the Pull Request URL in the YouTrack ticket

Ticket states:

* If you need the ticket's Pull Request reviewed, change the State to "Pull Request".
* If you are continuing development, change the State to "Open".
